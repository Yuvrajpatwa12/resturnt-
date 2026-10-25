<?php
/**
 * Notifications API
 * Handles fetching and marking notifications as read.
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';
require_once 'email_notification_common.php';

$action = $_GET['action'] ?? '';
$uid = $_GET['user_id'] ?? '';
$tid = $_GET['tenant_id'] ?? '';

if (empty($uid) || empty($tid)) {
    echo json_encode(["status" => "error", "message" => "Missing identification"]);
    exit;
}

try {
    switch ($action) {
        case 'get_notifications':
            if (filter_var($uid, FILTER_VALIDATE_EMAIL)) {
                $email = authenticatedCustomerEmail($conn, $tid);
                if ($email === null || strtolower($email) !== strtolower($uid)) {
                    http_response_code(401);
                    echo json_encode(["status" => "error", "message" => "Customer sign-in required"]);
                    break;
                }
            }
            $stmt = $conn->prepare("SELECT * FROM notifications WHERE user_id = ? AND tenant_id = ? ORDER BY created_at DESC");
            $stmt->bind_param("ss", $uid, $tid);
            $stmt->execute();
            $result = $stmt->get_result();
            $notifications = $result->fetch_all(MYSQLI_ASSOC);

            // Get unseen count
            $stmt_count = $conn->prepare("SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND tenant_id = ? AND is_read = 0");
            $stmt_count->bind_param("ss", $uid, $tid);
            $stmt_count->execute();
            $unseen_count = $stmt_count->get_result()->fetch_assoc()['count'];

            echo json_encode([
                "status" => "success",
                "data" => $notifications,
                "unseen_count" => (int)$unseen_count
            ]);
            break;

        case 'mark_as_read':
            if (filter_var($uid, FILTER_VALIDATE_EMAIL)) {
                $email = authenticatedCustomerEmail($conn, $tid);
                if ($email === null || strtolower($email) !== strtolower($uid)) {
                    http_response_code(401);
                    echo json_encode(["status" => "error", "message" => "Customer sign-in required"]);
                    break;
                }
            }
            $stmt = $conn->prepare("UPDATE notifications SET is_read = 1 WHERE tenant_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci AND LOWER(user_id) COLLATE utf8mb4_general_ci = LOWER(?) COLLATE utf8mb4_general_ci");
            $stmt->bind_param("ss", $tid, $uid);
            if ($stmt->execute()) {
                $ack = $conn->prepare("UPDATE notification_email_queue
                    SET status = 'acknowledged'
                    WHERE tenant_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci
                      AND LOWER(user_id) COLLATE utf8mb4_general_ci = LOWER(?) COLLATE utf8mb4_general_ci
                      AND (event_type != 'message'
                           OR created_at > DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 MINUTE))
                      AND status IN ('pending', 'processing')");
                $ack->bind_param("ss", $tid, $uid);
                $ack->execute();
                $ack->close();
                echo json_encode(["status" => "success"]);
            } else {
                echo json_encode(["status" => "error"]);
            }
            break;

        case 'acknowledge':
            $email = authenticatedCustomerEmail($conn, $tid);
            $data = json_decode(file_get_contents('php://input'), true);
            $notificationId = (int)($data['notification_id'] ?? 0);
            if ($email === null || strtolower($email) !== strtolower($uid) || $notificationId <= 0) {
                http_response_code(401);
                echo json_encode(["status" => "error", "message" => "Invalid customer session or notification"]);
                break;
            }

            $markRead = $conn->prepare("UPDATE notifications SET is_read = 1
                WHERE id = ? AND tenant_id = ? AND user_id = ?");
            $markRead->bind_param("iss", $notificationId, $tid, $uid);
            if (!$markRead->execute()) {
                http_response_code(500);
                echo json_encode(["status" => "error", "message" => "Could not acknowledge notification"]);
                $markRead->close();
                break;
            }
            $markRead->close();

            $ack = $conn->prepare("UPDATE notification_email_queue
                SET status = 'acknowledged'
                WHERE tenant_id = ? AND user_id = ? AND notification_id = ?
                    AND (event_type != 'message'
                         OR created_at > DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 MINUTE))
                    AND status IN ('pending', 'processing')");
            $ack->bind_param("ssi", $tid, $uid, $notificationId);
            if ($ack->execute()) {
                echo json_encode(["status" => "success"]);
            } else {
                http_response_code(500);
                echo json_encode(["status" => "error", "message" => "Could not acknowledge notification"]);
            }
            $ack->close();
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
