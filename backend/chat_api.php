<?php
// Deploy this file as public_html/saas_api/chat_api.php.
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';
require_once 'push_notifier.php';
require_once 'email_notification_common.php';

$action = $_GET['action'] ?? '';
$tid = $_GET['tenant_id'] ?? '';

if ($tid === '') {
    echo json_encode(["status" => "error", "message" => "Missing tenant_id"]);
    exit;
}

$conn->query("CREATE TABLE IF NOT EXISTS chat_messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    sender_id VARCHAR(100) NOT NULL,
    receiver_id VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) DEFAULT 'text',
    reply_to_id INT DEFAULT NULL,
    is_read TINYINT(1) DEFAULT 0,
    is_edited TINYINT(1) DEFAULT 0,
    is_deleted TINYINT(1) DEFAULT 0,
    is_delivered TINYINT(1) NOT NULL DEFAULT 1,
    is_follow_request TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

$column = $conn->query("SHOW COLUMNS FROM chat_messages LIKE 'is_delivered'");
if ($column && $column->num_rows === 0) {
    $conn->query("ALTER TABLE chat_messages ADD COLUMN is_delivered TINYINT(1) NOT NULL DEFAULT 1");
}
$column = $conn->query("SHOW COLUMNS FROM chat_messages LIKE 'is_follow_request'");
if ($column && $column->num_rows === 0) {
    $conn->query("ALTER TABLE chat_messages ADD COLUMN is_follow_request TINYINT(1) NOT NULL DEFAULT 0");
}

$conn->query("CREATE TABLE IF NOT EXISTS chat_typing_status (
    tenant_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(100) NOT NULL,
    typing_to VARCHAR(100) NOT NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, user_id, typing_to)
)");

function resolveSenderName($conn, $userId, $tenantId) {
    if ($userId === '') return 'Diner';

    $stmt = $conn->prepare("SELECT name FROM customers
        WHERE LOWER(email) = LOWER(?) AND (tenant_id = ? OR tenant_id = 'startups_main')
        AND name IS NOT NULL AND name != '' AND name != 'Guest' LIMIT 1");
    if ($stmt) {
        $stmt->bind_param("ss", $userId, $tenantId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!empty($row['name'])) return $row['name'];
    }

    $stmt = $conn->prepare("SELECT user_name FROM restaurant_presence
        WHERE LOWER(user_id) = LOWER(?) AND tenant_id = ?
        AND user_name IS NOT NULL AND user_name != '' LIMIT 1");
    if ($stmt) {
        $stmt->bind_param("ss", $userId, $tenantId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!empty($row['user_name'])) return $row['user_name'];
    }

    if (strpos($userId, '@') !== false) return ucfirst(explode('@', $userId)[0]);
    return 'Diner ' . substr($userId, -4);
}

function areMutualFollows($conn, $tenantId, $firstId, $secondId) {
    $stmt = $conn->prepare("SELECT 1 FROM user_follows a
        INNER JOIN user_follows b
            ON b.tenant_id COLLATE utf8mb4_general_ci = a.tenant_id COLLATE utf8mb4_general_ci
            AND b.follower_id COLLATE utf8mb4_general_ci = a.following_id COLLATE utf8mb4_general_ci
            AND b.following_id COLLATE utf8mb4_general_ci = a.follower_id COLLATE utf8mb4_general_ci
        WHERE a.tenant_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci
            AND a.follower_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci
            AND a.following_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci
        LIMIT 1");
    if (!$stmt) throw new Exception("Could not check follow relationship");
    $stmt->bind_param("sss", $tenantId, $firstId, $secondId);
    $stmt->execute();
    $isMutual = $stmt->get_result()->num_rows > 0;
    $stmt->close();
    return $isMutual;
}

function followsUser($conn, $tenantId, $followerId, $followingId) {
    $stmt = $conn->prepare("SELECT 1 FROM user_follows
        WHERE tenant_id = ? AND follower_id = ? AND following_id = ? LIMIT 1");
    if (!$stmt) throw new Exception("Could not check follow status");
    $stmt->bind_param("sss", $tenantId, $followerId, $followingId);
    $stmt->execute();
    $isFollowing = $stmt->get_result()->num_rows > 0;
    $stmt->close();
    return $isFollowing;
}

function notifyDeliveredMessage($conn, $tenantId, $senderId, $receiverId, $message) {
    $senderName = resolveSenderName($conn, $senderId, $tenantId);
    $title = "💬 Message from @$senderName";
    $stmt = $conn->prepare("INSERT INTO notifications
        (tenant_id, user_id, title, message, type, sender_id)
        VALUES (?, ?, ?, ?, 'message', ?)");
    if ($stmt) {
        $stmt->bind_param("sssss", $tenantId, $receiverId, $title, $message, $senderId);
        if ($stmt->execute()) {
            $notificationId = (int)$conn->insert_id;
            queueEmailNotification($conn, $tenantId, $receiverId, $notificationId, 'message');
            notifyUser($receiverId, $tenantId, $title, $message, 'message', $senderId, $notificationId);
        }
        $stmt->close();
    }
}

function deliverPendingMessages($conn, $tenantId, $firstId, $secondId) {
    $stmt = $conn->prepare("SELECT id, sender_id, receiver_id, message, is_deleted
        FROM chat_messages
        WHERE tenant_id = ? AND is_delivered = 0
        AND ((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?))
        ORDER BY id ASC");
    if (!$stmt) throw new Exception("Could not load pending messages");
    $stmt->bind_param("sssss", $tenantId, $firstId, $secondId, $secondId, $firstId);
    $stmt->execute();
    $pending = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    $update = $conn->prepare("UPDATE chat_messages SET is_delivered = 1
        WHERE id = ? AND tenant_id = ? AND is_delivered = 0");
    if (!$update) throw new Exception("Could not deliver pending messages");
    foreach ($pending as $message) {
        $id = (int)$message['id'];
        $update->bind_param("is", $id, $tenantId);
        $update->execute();
        if ($update->affected_rows === 1) {
            if (empty($message['is_deleted'])) {
                notifyDeliveredMessage(
                    $conn,
                    $tenantId,
                    $message['sender_id'],
                    $message['receiver_id'],
                    $message['message']
                );
            }
        }
    }
    $update->close();

    $reset = $conn->prepare("UPDATE chat_messages SET is_follow_request = 0
        WHERE tenant_id = ?
        AND ((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?))");
    if (!$reset) throw new Exception("Could not reset follow request state");
    $reset->bind_param("sssss", $tenantId, $firstId, $secondId, $secondId, $firstId);
    $reset->execute();
    $reset->close();
}

try {
    switch ($action) {
        case 'send':
            $data = json_decode(file_get_contents("php://input"), true) ?? [];
            $sid = trim((string)($data['sender_id'] ?? ''));
            $rid = trim((string)($data['receiver_id'] ?? ''));
            $msg = trim((string)($data['message'] ?? ''));
            $type = (string)($data['type'] ?? 'text');
            $replyTo = isset($data['reply_to_id']) ? (int)$data['reply_to_id'] : null;

            if ($sid === '' || $rid === '' || $sid === $rid || $msg === '') {
                echo json_encode(["status" => "error", "message" => "Missing or invalid sender, receiver or message"]);
                break;
            }

            $conn->begin_transaction();
            $follow = $conn->prepare("SELECT follower_id FROM user_follows
                WHERE tenant_id = ? AND follower_id = ? AND following_id = ? FOR UPDATE");
            if (!$follow) throw new Exception("Could not verify follow status");
            $follow->bind_param("sss", $tid, $sid, $rid);
            $follow->execute();
            $isFollowing = $follow->get_result()->num_rows > 0;
            $follow->close();

            if (!$isFollowing) {
                $conn->rollback();
                echo json_encode([
                    "status" => "error",
                    "code" => "follow_required",
                    "message" => "Follow this user before sending a message."
                ]);
                break;
            }
            $isMutual = areMutualFollows($conn, $tid, $sid, $rid);
            $countStmt = $conn->prepare("SELECT COUNT(*) AS sent_count FROM chat_messages
                WHERE tenant_id = ? AND sender_id = ? AND receiver_id = ?
                AND (is_follow_request = 1 OR is_delivered = 0)");
            if (!$countStmt) throw new Exception("Could not check message request limit");
            $countStmt->bind_param("sss", $tid, $sid, $rid);
            $countStmt->execute();
            $sentCount = (int)$countStmt->get_result()->fetch_assoc()['sent_count'];
            $countStmt->close();

            $delivered = ($isMutual || $sentCount < 2) ? 1 : 0;
            $isFollowRequest = $isMutual ? 0 : 1;
            $stmt = $conn->prepare("INSERT INTO chat_messages
                (tenant_id, sender_id, receiver_id, message, type, reply_to_id, is_delivered, is_follow_request)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
            if (!$stmt) throw new Exception("Could not prepare message");
            $stmt->bind_param("sssssiii", $tid, $sid, $rid, $msg, $type, $replyTo, $delivered, $isFollowRequest);
            if (!$stmt->execute()) throw new Exception("Message could not be saved");
            $messageId = (int)$conn->insert_id;
            $conn->commit();

            if ($isMutual) deliverPendingMessages($conn, $tid, $sid, $rid);
            $senderName = resolveSenderName($conn, $sid, $tid);
            if ($delivered) notifyDeliveredMessage($conn, $tid, $sid, $rid, $msg);

            echo json_encode([
                "status" => "success",
                "id" => $messageId,
                "sender_name" => $senderName,
                "is_mutual" => $isMutual,
                "delivered" => (bool)$delivered,
                "sent_before_follow_back" => $isMutual ? 0 : $sentCount + 1
            ]);
            break;

        case 'sync':
            $uid1 = (string)($_GET['uid1'] ?? '');
            $uid2 = (string)($_GET['uid2'] ?? '');
            $lastId = (int)($_GET['last_id'] ?? 0);
            if ($uid1 === '' || $uid2 === '') {
                echo json_encode(["status" => "error", "message" => "Missing chat participants"]);
                break;
            }

            $isMutual = areMutualFollows($conn, $tid, $uid1, $uid2);
            $isFollowing = followsUser($conn, $tid, $uid1, $uid2);
            if ($isMutual) deliverPendingMessages($conn, $tid, $uid1, $uid2);

            $stmt = $conn->prepare("SELECT * FROM chat_messages
                WHERE tenant_id = ?
                AND ((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?))
                AND ((id > ? AND (is_delivered = 1 OR sender_id = ?))
                    OR (receiver_id = ? AND is_delivered = 1 AND is_read = 0))
                ORDER BY id ASC LIMIT 100");
            $stmt->bind_param("sssssiss", $tid, $uid1, $uid2, $uid2, $uid1, $lastId, $uid1, $uid1);
            $stmt->execute();
            $messages = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            $stmt->close();

            $typingStmt = $conn->prepare("SELECT 1 FROM chat_typing_status
                WHERE tenant_id = ? AND user_id = ? AND typing_to = ?
                AND last_updated > DATE_SUB(NOW(), INTERVAL 5 SECOND)");
            $typingStmt->bind_param("sss", $tid, $uid2, $uid1);
            $typingStmt->execute();
            $isTyping = $typingStmt->get_result()->num_rows > 0;
            $typingStmt->close();

            $countStmt = $conn->prepare("SELECT COUNT(*) AS sent_count FROM chat_messages
                WHERE tenant_id = ? AND sender_id = ? AND receiver_id = ?
                AND (is_follow_request = 1 OR is_delivered = 0)");
            $countStmt->bind_param("sss", $tid, $uid1, $uid2);
            $countStmt->execute();
            $sentCount = (int)$countStmt->get_result()->fetch_assoc()['sent_count'];
            $countStmt->close();

            echo json_encode([
                "status" => "success",
                "messages" => $messages,
                "is_typing" => $isTyping,
                "is_mutual" => $isMutual,
                "is_following" => $isFollowing,
                "sent_before_follow_back" => $isMutual ? 0 : $sentCount
            ]);
            break;

        case 'get_conversations':
            $myId = (string)($_GET['user_id'] ?? '');
            if ($myId === '') {
                echo json_encode(["status" => "success", "data" => []]);
                break;
            }

            $stmt = $conn->prepare("SELECT DISTINCT
                    CASE WHEN follower_id = ? THEN following_id ELSE follower_id END AS friend_id
                FROM user_follows
                WHERE tenant_id = ? AND (follower_id = ? OR following_id = ?)
                AND (follower_id, following_id, tenant_id) IN
                    (SELECT following_id, follower_id, tenant_id FROM user_follows)");
            $stmt->bind_param("ssss", $myId, $tid, $myId, $myId);
            $stmt->execute();
            $friends = $stmt->get_result();
            $conversations = [];

            while ($friend = $friends->fetch_assoc()) {
                $friendId = $friend['friend_id'];
                deliverPendingMessages($conn, $tid, $myId, $friendId);
                $profileStmt = $conn->prepare("SELECT name, gender FROM customers
                    WHERE tenant_id = ? AND LOWER(email) = LOWER(?) LIMIT 1");
                $profileStmt->bind_param("ss", $tid, $friendId);
                $profileStmt->execute();
                $profile = $profileStmt->get_result()->fetch_assoc();
                $profileStmt->close();

                $lastStmt = $conn->prepare("SELECT message, created_at, sender_id, is_read, is_deleted
                    FROM chat_messages WHERE tenant_id = ?
                    AND ((sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?))
                    AND is_delivered = 1 ORDER BY id DESC LIMIT 1");
                $lastStmt->bind_param("sssss", $tid, $myId, $friendId, $friendId, $myId);
                $lastStmt->execute();
                $lastMessage = $lastStmt->get_result()->fetch_assoc();
                $lastStmt->close();

                $unreadStmt = $conn->prepare("SELECT COUNT(*) AS count FROM chat_messages
                    WHERE tenant_id = ? AND sender_id = ? AND receiver_id = ?
                    AND is_read = 0 AND is_deleted = 0 AND is_delivered = 1");
                $unreadStmt->bind_param("sss", $tid, $friendId, $myId);
                $unreadStmt->execute();
                $unread = (int)$unreadStmt->get_result()->fetch_assoc()['count'];
                $unreadStmt->close();

                $conversations[] = [
                    "uid" => $friendId,
                    "name" => $profile['name'] ?? resolveSenderName($conn, $friendId, $tid),
                    "gender" => $profile['gender'] ?? "Male",
                    "last_msg" => $lastMessage
                        ? (!empty($lastMessage['is_deleted']) ? "Message unsent" : $lastMessage['message'])
                        : "Start a conversation",
                    "last_time" => $lastMessage['created_at'] ?? null,
                    "unread" => $unread,
                    "is_me_last" => $lastMessage ? $lastMessage['sender_id'] === $myId : false
                ];
            }
            $stmt->close();
            echo json_encode(["status" => "success", "data" => $conversations]);
            break;

        case 'deliver_pending':
            $data = json_decode(file_get_contents("php://input"), true) ?? [];
            $firstId = trim((string)($data['user_id'] ?? ''));
            $secondId = trim((string)($data['other_user_id'] ?? ''));
            if ($firstId === '' || $secondId === '' || $firstId === $secondId) {
                echo json_encode(["status" => "error", "message" => "Missing chat participants"]);
                break;
            }
            if (!areMutualFollows($conn, $tid, $firstId, $secondId)) {
                echo json_encode(["status" => "error", "code" => "not_mutual"]);
                break;
            }
            deliverPendingMessages($conn, $tid, $firstId, $secondId);
            echo json_encode(["status" => "success"]);
            break;

        case 'typing':
            $data = json_decode(file_get_contents("php://input"), true) ?? [];
            $uid = (string)($data['user_id'] ?? '');
            $to = (string)($data['typing_to'] ?? '');
            if ($uid !== '' && $to !== '') {
                $stmt = $conn->prepare("INSERT INTO chat_typing_status (tenant_id, user_id, typing_to)
                    VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE last_updated = CURRENT_TIMESTAMP");
                $stmt->bind_param("sss", $tid, $uid, $to);
                $stmt->execute();
                $stmt->close();
            }
            echo json_encode(["status" => "success"]);
            break;

        case 'mark_read':
            $myId = (string)($_GET['my_id'] ?? '');
            $fromId = (string)($_GET['from_id'] ?? '');
            $stmt = $conn->prepare("UPDATE chat_messages SET is_read = 1
                WHERE tenant_id = ? AND sender_id = ? AND receiver_id = ?
                AND is_read = 0 AND is_delivered = 1");
            $stmt->bind_param("sss", $tid, $fromId, $myId);
            $stmt->execute();
            $notifications = $conn->prepare("UPDATE notifications SET is_read = 1
                WHERE tenant_id = ? AND user_id = ? AND sender_id = ? AND type = 'message'");
            $notifications->bind_param("sss", $tid, $myId, $fromId);
            $notifications->execute();
            $notifications->close();
            $acknowledge = $conn->prepare("UPDATE notification_email_queue q
                INNER JOIN notifications n
                    ON n.id = q.notification_id
                    AND n.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci
                SET q.status = 'acknowledged'
                WHERE q.tenant_id = ? AND q.user_id = ? AND q.event_type = 'message'
                    AND q.status IN ('pending', 'processing')
                    AND q.created_at > DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 MINUTE)
                    AND n.sender_id = ? AND n.type = 'message'");
            if ($acknowledge) {
                $acknowledge->bind_param("sss", $tid, $myId, $fromId);
                $acknowledge->execute();
                $acknowledge->close();
            }
            echo json_encode(["status" => "success"]);
            break;

        case 'edit':
            $data = json_decode(file_get_contents("php://input"), true) ?? [];
            $messageId = (int)($data['message_id'] ?? 0);
            $newText = trim((string)($data['message'] ?? ''));
            $userId = (string)($data['user_id'] ?? '');
            $stmt = $conn->prepare("UPDATE chat_messages SET message = ?, is_edited = 1
                WHERE id = ? AND sender_id = ? AND tenant_id = ?");
            $stmt->bind_param("siss", $newText, $messageId, $userId, $tid);
            $stmt->execute();
            echo json_encode(["status" => "success"]);
            break;

        case 'delete':
            $data = json_decode(file_get_contents("php://input"), true) ?? [];
            $messageId = (int)($data['message_id'] ?? 0);
            $userId = (string)($data['user_id'] ?? '');
            $stmt = $conn->prepare("UPDATE chat_messages SET is_deleted = 1, message = 'Message unsent'
                WHERE id = ? AND sender_id = ? AND tenant_id = ?");
            $stmt->bind_param("iss", $messageId, $userId, $tid);
            $stmt->execute();
            echo json_encode(["status" => "success"]);
            break;

        default:
            echo json_encode(["status" => "error", "message" => "Invalid action"]);
            break;
    }
} catch (Throwable $e) {
    if ($conn->thread_id) $conn->rollback();
    error_log('Chat API action "' . $action . '" failed: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Chat request failed"]);
}

$conn->close();
?>
