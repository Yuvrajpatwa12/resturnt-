<?php
/**
 * Notifications API
 * Handles fetching and marking notifications as read.
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';

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
            $stmt = $conn->prepare("UPDATE notifications SET is_read = 1 WHERE user_id = ? AND tenant_id = ?");
            $stmt->bind_param("ss", $uid, $tid);
            if ($stmt->execute()) {
                echo json_encode(["status" => "success"]);
            } else {
                echo json_encode(["status" => "error"]);
            }
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
