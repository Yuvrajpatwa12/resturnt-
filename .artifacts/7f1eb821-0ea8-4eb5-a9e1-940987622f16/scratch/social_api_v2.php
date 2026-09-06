<?php
/**
 * Social API V2 (Advanced)
 * Handles Following, Requests, and Friends lists.
 */
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once 'db_config.php';

$action = $_GET['action'] ?? '';
$uid = $_GET['user_id'] ?? '';
$tid = $_GET['tenant_id'] ?? '';

if (empty($uid) || empty($tid)) {
    echo json_encode(["status" => "error", "message" => "Missing IDs"]);
    exit;
}

try {
    switch ($action) {
        case 'get_following':
            // Users I follow
            $sql = "SELECT c.email, c.name, c.gender, c.points
                    FROM user_follows f
                    JOIN customers c ON f.following_id = c.email AND f.tenant_id = c.tenant_id
                    WHERE f.follower_id = ? AND f.tenant_id = ?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("ss", $uid, $tid);
            $stmt->execute();
            echo json_encode(["status" => "success", "data" => $stmt->get_result()->fetch_all(MYSQLI_ASSOC)]);
            break;

        case 'get_requests':
            // Users following me, but I am NOT following them back
            $sql = "SELECT c.email, c.name, c.gender
                    FROM user_follows f
                    JOIN customers c ON f.follower_id = c.email AND f.tenant_id = c.tenant_id
                    WHERE f.following_id = ? AND f.tenant_id = ?
                    AND f.follower_id NOT IN (SELECT following_id FROM user_follows WHERE follower_id = ? AND tenant_id = ?)";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("ssss", $uid, $tid, $uid, $tid);
            $stmt->execute();
            echo json_encode(["status" => "success", "data" => $stmt->get_result()->fetch_all(MYSQLI_ASSOC)]);
            break;

        case 'get_friends':
            // Mutual follows
            $sql = "SELECT c.email, c.name, c.gender
                    FROM user_follows f1
                    JOIN user_follows f2 ON f1.follower_id = f2.following_id AND f1.following_id = f2.follower_id AND f1.tenant_id = f2.tenant_id
                    JOIN customers c ON f1.following_id = c.email AND f1.tenant_id = c.tenant_id
                    WHERE f1.follower_id = ? AND f1.tenant_id = ?";
            $stmt = $conn->prepare($sql);
            $stmt->bind_param("ss", $uid, $tid);
            $stmt->execute();
            echo json_encode(["status" => "success", "data" => $stmt->get_result()->fetch_all(MYSQLI_ASSOC)]);
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
