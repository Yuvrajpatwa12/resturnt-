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
                    (SELECT COUNT(*) FROM user_follows WHERE follower_id = ? AND following_id = p.user_id AND tenant_id = p.tenant_id) as is_following,
                    (SELECT COUNT(*) FROM user_follows WHERE follower_id = p.user_id AND following_id = ? AND tenant_id = p.tenant_id) as follows_me
                    FROM restaurant_presence p
                    WHERE p.tenant_id = ? AND p.last_seen > (NOW() - INTERVAL 60 MINUTE)
                    GROUP BY p.user_id
                    ORDER BY p.last_seen DESC";

            $stmt = $conn->prepare($sql);
            $stmt->bind_param("sss", $my_id, $my_id, $tenant_id);
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
                    $name_res = $conn->query("SELECT name FROM customers WHERE email = '$my_id' AND tenant_id = '$tid'");
                    $my_name = ($name_res && $row = $name_res->fetch_assoc()) ? $row['name'] : 'Someone';

                    $notif_title = "New Follower!";
                    $notif_msg = "@$my_name just followed your profile.";
                    $notif_ins = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type, sender_id) VALUES (?, ?, ?, ?, 'follow', ?)");
                    $notif_ins->bind_param("sssss", $tid, $target_id, $notif_title, $notif_msg, $my_id);
                    $notif_ins->execute();

                    // Check for Mutual friendship
                    $mutual = $conn->query("SELECT id FROM user_follows WHERE follower_id = '$target_id' AND following_id = '$my_id' AND tenant_id = '$tid'");
                    if ($mutual->num_rows > 0) {
                         $f_title = "Mutual Connection!";
                         $f_msg = "You and @$my_name are now friends. Start chatting!";
                         $notif_ins->bind_param("sssss", $tid, $target_id, $f_title, $f_msg, $my_id);
                         $notif_ins->execute();
                    }
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
                $name_res = $conn->query("SELECT name FROM customers WHERE email = '$sender' AND tenant_id = '$tid'");
                $s_name = ($name_res && $row = $name_res->fetch_assoc()) ? $row['name'] : 'Someone';

                $notif_title = "Digital Wave!";
                $notif_msg = "@$s_name waved at you from their table.";
                $notif_ins = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type, sender_id) VALUES (?, ?, ?, ?, 'wave', ?)");
                $notif_ins->bind_param("sssss", $tid, $receiver, $notif_title, $notif_msg, $sender);
                $notif_ins->execute();

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
} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}

$conn->close();
?>
