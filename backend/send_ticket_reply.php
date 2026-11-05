<?php
/**
 * send_ticket_reply.php - Standalone & Backward-Compatible Support Ticket Reply Endpoint
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// 1. Try forwarding to unified support_tickets_api.php if available
if (file_exists('support_tickets_api.php')) {
    $_GET['action'] = 'send_reply';
    require_once 'support_tickets_api.php';
    exit;
}

// 2. Standalone Database Fallback
if (file_exists('db_config.php')) {
    require_once 'db_config.php';
} else if (file_exists('db_connect.php')) {
    require_once 'db_connect.php';
} else {
    echo json_encode(["status" => "error", "message" => "Database config file missing."]);
    exit;
}

$json = file_get_contents('php://input');
$data = json_decode($json);

$ticket_id = intval($data->ticket_id ?? $_POST['ticket_id'] ?? 0);
$message = trim((string)($data->message ?? $_POST['message'] ?? ''));
$sender_type = trim((string)($data->sender_type ?? $data->sender ?? $_POST['sender_type'] ?? 'Tenant'));

if ($ticket_id <= 0 || empty($message)) {
    echo json_encode(["status" => "error", "message" => "Valid Ticket ID and Message required."]);
    exit;
}

try {
    @$conn->query("CREATE TABLE IF NOT EXISTS support_ticket_replies (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ticket_id INT NOT NULL,
        sender VARCHAR(100) DEFAULT 'Tenant',
        sender_type VARCHAR(50) DEFAULT 'Tenant',
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $stmt = $conn->prepare("INSERT INTO support_ticket_replies (ticket_id, sender, sender_type, message) VALUES (?, ?, ?, ?)");
    $stmt->bind_param("isss", $ticket_id, $sender_type, $sender_type, $message);
    $stmt->execute();

    // Trigger email notification if helper available
    if (file_exists('email_notification_common.php')) {
        require_once 'email_notification_common.php';
        $t_stmt = $conn->prepare("SELECT tenant_id FROM support_tickets WHERE id = ? LIMIT 1");
        if ($t_stmt) {
            $t_stmt->bind_param("i", $ticket_id);
            $t_stmt->execute();
            $t_res = $t_stmt->get_result();
            if ($t_row = $t_res->fetch_assoc()) {
                $tenant_id = $t_row['tenant_id'];
                $admin_stmt = $conn->prepare("SELECT contact_email, primary_email FROM tenants WHERE tenant_id = ? LIMIT 1");
                $admin_stmt->bind_param("s", $tenant_id);
                $admin_stmt->execute();
                $admin_res = $admin_stmt->get_result();
                $admin_email = '';
                if ($admin_row = $admin_res->fetch_assoc()) {
                    if (!empty($admin_row['contact_email'])) $admin_email = $admin_row['contact_email'];
                    else if (!empty($admin_row['primary_email'])) $admin_email = $admin_row['primary_email'];
                }

                if (filter_var($admin_email, FILTER_VALIDATE_EMAIL)) {
                    $notif = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type) VALUES (?, ?, 'Support Reply', ?, 'support_reply')");
                    $notif->bind_param("sss", $tenant_id, $admin_email, $message);
                    if ($notif->execute()) {
                        queueEmailNotification($conn, $tenant_id, $admin_email, $conn->insert_id, 'support_reply');
                    }
                } else {
                    error_log(
                        "Support reply notification skipped: no valid admin email for tenant " .
                        $tenant_id
                    );
                }
            }
        }
    }

    echo json_encode(["status" => "success", "message" => "Reply sent successfully."]);
} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}
?>
