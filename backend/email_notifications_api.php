<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';
require_once 'email_notification_common.php';

$tenantId = trim((string)($_GET['tenant_id'] ?? ''));
$action = (string)($_GET['action'] ?? '');
$email = $tenantId === '' ? null : authenticatedCustomerEmail($conn, $tenantId);

if ($action === 'logout' && $_SERVER['REQUEST_METHOD'] === 'POST' && $email !== null) {
    $tokenHash = customerSessionTokenHash();
    $stmt = $conn->prepare("DELETE FROM customer_auth_sessions
        WHERE token_hash = ? AND tenant_id = ? AND email = ?");
    $stmt->bind_param("sss", $tokenHash, $tenantId, $email);
    $stmt->execute();
    echo json_encode(["status" => "success"]);
    $conn->close();
    exit;
}

if ($email === null) {
    http_response_code(401);
    echo json_encode(["status" => "error", "message" => "Customer sign-in required"]);
    exit;
}

try {
    if ($action === 'get_preferences' && $_SERVER['REQUEST_METHOD'] === 'GET') {
        $stmt = $conn->prepare("SELECT email_enabled, email_follow, email_wave, email_message
            FROM customer_notification_email_preferences WHERE tenant_id = ? AND email = ? LIMIT 1");
        $stmt->bind_param("ss", $tenantId, $email);
        $stmt->execute();
        $preferences = $stmt->get_result()->fetch_assoc();
        echo json_encode([
            "status" => "success",
            "preferences" => $preferences ?: [
                "email_enabled" => 0,
                "email_follow" => 1,
                "email_wave" => 1,
                "email_message" => 1
            ]
        ]);
    } elseif ($action === 'save_preferences' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        $data = json_decode(file_get_contents('php://input'), true);
        if (!is_array($data)) {
            http_response_code(400);
            echo json_encode(["status" => "error", "message" => "Invalid preferences"]);
            exit;
        }

        $enabled = !empty($data['email_enabled']) ? 1 : 0;
        $follow = !empty($data['email_follow']) ? 1 : 0;
        $wave = !empty($data['email_wave']) ? 1 : 0;
        $message = !empty($data['email_message']) ? 1 : 0;
        $stmt = $conn->prepare("INSERT INTO customer_notification_email_preferences
            (tenant_id, email, email_enabled, email_follow, email_wave, email_message)
            VALUES (?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE email_enabled = VALUES(email_enabled),
                email_follow = VALUES(email_follow), email_wave = VALUES(email_wave),
                email_message = VALUES(email_message), updated_at = CURRENT_TIMESTAMP");
        $stmt->bind_param("ssiiii", $tenantId, $email, $enabled, $follow, $wave, $message);
        if (!$stmt->execute()) throw new Exception("Could not save email preferences");

        if ($enabled === 0) {
            $cancel = $conn->prepare("UPDATE notification_email_queue
                SET status = 'skipped'
                WHERE tenant_id = ? AND user_id = ? AND status IN ('pending', 'processing')");
            $cancel->bind_param("ss", $tenantId, $email);
            $cancel->execute();
            $cancel->close();
        } else {
            $disabledTypes = [];
            if ($follow === 0) $disabledTypes = array_merge($disabledTypes, ['follow', 'follow_back']);
            if ($wave === 0) $disabledTypes[] = 'wave';
            if ($message === 0) $disabledTypes[] = 'message';
            foreach ($disabledTypes as $eventType) {
                $cancel = $conn->prepare("UPDATE notification_email_queue
                    SET status = 'skipped'
                    WHERE tenant_id = ? AND user_id = ? AND event_type = ?
                        AND status IN ('pending', 'processing')");
                $cancel->bind_param("sss", $tenantId, $email, $eventType);
                $cancel->execute();
                $cancel->close();
            }
        }

        echo json_encode(["status" => "success"]);
    } else {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Invalid action"]);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}

$conn->close();
