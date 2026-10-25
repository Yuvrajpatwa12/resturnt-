<?php
/**
 * Nearby Discovery & Social API (V3 - Final Production)
 * Handles real-time check-ins, fetching active guests, follows, and waves.
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';
require_once 'push_notifier.php';
require_once 'email_notification_common.php';

$conn->query("CREATE TABLE IF NOT EXISTS user_privacy_settings (
    tenant_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(190) NOT NULL,
    is_public TINYINT(1) NOT NULL DEFAULT 1,
    allow_waves TINYINT(1) NOT NULL DEFAULT 1,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Database connection failed"]));
}

$action = $_GET['action'] ?? '';
$tenant_id = $_GET['tenant_id'] ?? '';

try {
    switch ($action) {
        case 'check_in':
            $data = json_decode(file_get_contents('php://input'));
            if (!$data || empty($data->user_id)) {
                echo json_encode(["status" => "error", "message" => "Invalid data"]);
                exit;
            }

            $uid = (string)$data->user_id;
            $tid = (string)$data->tenant_id;
            $tnum = (int)$data->table_number;
            $uimg = $data->user_image ?? '';

            // Fix "0" name bug
            $uname = (string)($data->user_name ?? '');
            if (empty($uname) || $uname == "0" || $uname == "null") {
                $uname = "Diner " . substr($uid, -4);
            }

            $stmt = $conn->prepare("INSERT INTO restaurant_presence (user_id, tenant_id, table_number, user_name, user_image, last_seen)
                                    VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
                                    ON DUPLICATE KEY UPDATE
                                    table_number = ?, user_name = ?, user_image = ?, last_seen = CURRENT_TIMESTAMP");

            $stmt->bind_param("ssississ", $uid, $tid, $tnum, $uname, $uimg, $tnum, $uname, $uimg);

            if ($stmt->execute()) {
                echo json_encode(["status" => "success", "message" => "Checked in"]);
            } else {
                echo json_encode(["status" => "error", "message" => "Execute failed: " . $stmt->error]);
            }
            break;

        case 'get_active_users':
            $my_id = $_GET['user_id'] ?? '';
            // Fetch users seen in the last 60 minutes + Follow Status
            // Use GROUP BY to avoid duplicates
            $sql = "SELECT p.*,
                    COALESCE(privacy.is_public, 1) AS is_public,
                    COALESCE(privacy.allow_waves, 1) AS allow_waves,
                    (SELECT COUNT(*) FROM user_follows f
                        WHERE f.follower_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci
                            AND f.following_id COLLATE utf8mb4_general_ci = p.user_id COLLATE utf8mb4_general_ci
                            AND f.tenant_id COLLATE utf8mb4_general_ci = p.tenant_id COLLATE utf8mb4_general_ci) as is_following,
                    (SELECT COUNT(*) FROM user_follows f
                        WHERE f.follower_id COLLATE utf8mb4_general_ci = p.user_id COLLATE utf8mb4_general_ci
                            AND f.following_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci
                            AND f.tenant_id COLLATE utf8mb4_general_ci = p.tenant_id COLLATE utf8mb4_general_ci) as follows_me
                    FROM restaurant_presence p
                    LEFT JOIN user_privacy_settings privacy
                        ON privacy.tenant_id COLLATE utf8mb4_general_ci = p.tenant_id COLLATE utf8mb4_general_ci
                            AND privacy.user_id COLLATE utf8mb4_general_ci = p.user_id COLLATE utf8mb4_general_ci
                    WHERE p.tenant_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci
                        AND p.last_seen > (NOW() - INTERVAL 60 MINUTE)
                        AND (COALESCE(privacy.is_public, 1) = 1
                            OR p.user_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci)
                    ORDER BY p.last_seen DESC";

            $stmt = $conn->prepare($sql);
            $stmt->bind_param("ssss", $my_id, $my_id, $tenant_id, $my_id);
            $stmt->execute();
            $result = $stmt->get_result();

            $users = [];
            while ($row = $result->fetch_assoc()) {
                $users[] = $row;
            }
            echo json_encode(["status" => "success", "data" => $users]);
            break;

        case 'toggle_follow':
            $data = json_decode(file_get_contents('php://input'));
            $my_id = (string)($data->user_id ?? '');
            $target_id = (string)($data->target_id ?? '');
            $tid = (string)($data->tenant_id ?? '');

            if (empty($my_id) || empty($target_id) || $my_id == $target_id) {
                echo json_encode(["status" => "error", "message" => "Invalid request"]);
                exit;
            }

            // Check current status
            $check = $conn->prepare("SELECT id FROM user_follows WHERE follower_id = ? AND following_id = ? AND tenant_id = ?");
            $check->bind_param("sss", $my_id, $target_id, $tid);
            $check->execute();
            $res = $check->get_result();

            $is_now_following = false;
            if ($res->num_rows > 0) {
                // Unfollow
                $stmt = $conn->prepare("DELETE FROM user_follows WHERE follower_id = ? AND following_id = ? AND tenant_id = ?");
                $is_now_following = false;
            } else {
                // Follow
                $stmt = $conn->prepare("INSERT INTO user_follows (follower_id, following_id, tenant_id) VALUES (?, ?, ?)");
                $is_now_following = true;
            }
            $stmt->bind_param("sss", $my_id, $target_id, $tid);

            if ($stmt->execute()) {
                // Notifications logic
                if ($is_now_following) {
                    $name_stmt = $conn->prepare("SELECT name FROM customers WHERE email = ? AND tenant_id = ? LIMIT 1");
                    $name_stmt->bind_param("ss", $my_id, $tid);
                    $name_stmt->execute();
                    $name_res = $name_stmt->get_result();
                    $my_name = ($name_res && $row = $name_res->fetch_assoc()) ? $row['name'] : 'Someone';
                    $name_stmt->close();

                    $notif_title = "New Follower!";
                    $notif_msg = "@$my_name just followed your profile.";
                    $notif_ins = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type, sender_id) VALUES (?, ?, ?, ?, 'follow', ?)");
                    $notif_ins->bind_param("sssss", $tid, $target_id, $notif_title, $notif_msg, $my_id);
                    if ($notif_ins->execute()) {
                        $notification_id = (int)$conn->insert_id;
                        queueEmailNotification($conn, $tid, $target_id, $notification_id, 'follow');
                        notifyUser($target_id, $tid, $notif_title, $notif_msg, 'follow', $my_id, $notification_id);
                    }

                    // Check for Mutual friendship
                    $mutual_stmt = $conn->prepare("SELECT id FROM user_follows
                        WHERE follower_id = ? AND following_id = ? AND tenant_id = ? LIMIT 1");
                    $mutual_stmt->bind_param("sss", $target_id, $my_id, $tid);
                    $mutual_stmt->execute();
                    $is_mutual = $mutual_stmt->get_result()->num_rows > 0;
                    $mutual_stmt->close();
                    if ($is_mutual) {
                         $f_title = "Mutual Connection!";
                         $f_msg = "You and @$my_name are now friends. Start chatting!";
                         $f_type = 'follow_back';
                         $notif_ins->bind_param("sssss", $tid, $target_id, $f_title, $f_msg, $my_id);
                         if ($notif_ins->execute()) {
                             $notification_id = (int)$conn->insert_id;
                             queueEmailNotification($conn, $tid, $target_id, $notification_id, $f_type);
                             notifyUser($target_id, $tid, $f_title, $f_msg, $f_type, $my_id, $notification_id);
                         }
                    }
                    $notif_ins->close();
                }
                echo json_encode(["status" => "success", "following" => $is_now_following]);
            } else {
                echo json_encode(["status" => "error", "message" => "Database error: " . $stmt->error]);
            }
            break;

        case 'get_social_stats':
            $uid = (string)($_GET['user_id'] ?? '');
            $tid = (string)($_GET['tenant_id'] ?? '');

            $followers = $conn->query("SELECT COUNT(*) as cnt FROM user_follows WHERE following_id = '$uid' AND tenant_id = '$tid'")->fetch_assoc()['cnt'];
            $following = $conn->query("SELECT COUNT(*) as cnt FROM user_follows WHERE follower_id = '$uid' AND tenant_id = '$tid'")->fetch_assoc()['cnt'];

            $sql = "SELECT COUNT(*) as cnt FROM user_follows f1
                    JOIN user_follows f2 ON f1.follower_id = f2.following_id AND f1.following_id = f2.follower_id
                    WHERE f1.follower_id = ? AND f1.tenant_id = ?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("ss", $uid, $tid);
            $stmt->execute();
            $connections = $stmt->get_result()->fetch_assoc()['cnt'];

            echo json_encode(["status" => "success", "followers" => (int)$followers, "following" => (int)$following, "connections" => (int)$connections]);
            break;

        case 'send_wave':
            $data = json_decode(file_get_contents('php://input'));
            $sender = (string)$data->sender_id;
            $receiver = (string)$data->receiver_id;
            $tid = (string)$data->tenant_id;

            $stmt = $conn->prepare("INSERT INTO user_waves (sender_id, receiver_id, tenant_id) VALUES (?, ?, ?)");
            $stmt->bind_param("sss", $sender, $receiver, $tid);
            if ($stmt->execute()) {
                $name_stmt = $conn->prepare("SELECT name FROM customers WHERE email = ? AND tenant_id = ? LIMIT 1");
                $name_stmt->bind_param("ss", $sender, $tid);
                $name_stmt->execute();
                $name_res = $name_stmt->get_result();
                $s_name = ($name_res && $row = $name_res->fetch_assoc()) ? $row['name'] : 'Someone';
                $name_stmt->close();

                $notif_title = "Digital Wave!";
                $notif_msg = "@$s_name waved at you from their table.";
                $notif_ins = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type, sender_id) VALUES (?, ?, ?, ?, 'wave', ?)");
                $notif_ins->bind_param("sssss", $tid, $receiver, $notif_title, $notif_msg, $sender);
                if ($notif_ins->execute()) {
                    $notification_id = (int)$conn->insert_id;
                    queueEmailNotification($conn, $tid, $receiver, $notification_id, 'wave');
                    notifyUser($receiver, $tid, $notif_title, $notif_msg, 'wave', $sender, $notification_id);
                }
                $notif_ins->close();

                echo json_encode(["status" => "success"]);
            } else {
                echo json_encode(["status" => "error"]);
            }
            break;

        case 'get_waves':
            $uid = (string)($_GET['user_id'] ?? '');
            $tid = (string)($_GET['tenant_id'] ?? '');

            $stmt = $conn->prepare("SELECT w.id, p.user_name FROM user_waves w
                                    LEFT JOIN restaurant_presence p ON w.sender_id = p.user_id
                                    WHERE w.receiver_id = ? AND w.tenant_id = ? AND w.is_delivered = 0");
            $stmt->bind_param("ss", $uid, $tid);
            $stmt->execute();
            $result = $stmt->get_result();
            $waves = $result->fetch_all(MYSQLI_ASSOC);

            if (!empty($waves)) {
                $conn->query("UPDATE user_waves SET is_delivered = 1 WHERE receiver_id = '$uid' AND tenant_id = '$tid'");
            }
            echo json_encode(["status" => "success", "data" => $waves]);
            break;

        default:
            echo json_encode(["status" => "error", "message" => "Invalid action"]);
            break;
    }
} catch (Throwable $e) {
    error_log('Nearby API action "' . $action . '" failed: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Nearby request failed"]);
}

$conn->close();
?>
