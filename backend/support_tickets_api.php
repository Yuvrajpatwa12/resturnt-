<?php
/**
 * support_tickets_api.php - Real-Time Support Tickets & Notification Dispatcher
 */

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';
require_once 'super_admin_api.php';
require_once 'email_notification_common.php';

// Auto-run schema migrations
try {
    @$conn->query("CREATE TABLE IF NOT EXISTS support_tickets (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(100) NOT NULL,
        subject VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        status VARCHAR(50) DEFAULT 'Open',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    @$conn->query("CREATE TABLE IF NOT EXISTS support_ticket_replies (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ticket_id INT NOT NULL,
        sender VARCHAR(100) NOT NULL,
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
} catch (Throwable $e) {}

$action = $_GET['action'] ?? '';

try {
    switch ($action) {
        case 'get_tickets':
            $tenant_id = trim((string)($_GET['tenant_id'] ?? ''));
            if (!empty($tenant_id)) {
                $stmt = $conn->prepare("SELECT * FROM support_tickets WHERE tenant_id = ? ORDER BY created_at DESC");
                $stmt->bind_param("s", $tenant_id);
            } else {
                $stmt = $conn->prepare("SELECT t.*, tn.restaurant_name FROM support_tickets t LEFT JOIN tenants tn ON tn.tenant_id = t.tenant_id ORDER BY t.created_at DESC");
            }
            $stmt->execute();
            $res = $stmt->get_result();
            $tickets = [];
            while ($row = $res->fetch_assoc()) {
                $tickets[] = $row;
            }
            echo json_encode(["status" => "success", "data" => $tickets]);
            break;

        case 'create_ticket':
            $json = file_get_contents('php://input');
            $data = json_decode($json);

            $tenant_id = trim((string)($data->tenant_id ?? 'startups_main'));
            $subject = trim((string)($data->subject ?? 'Support Request'));
            $message = trim((string)($data->message ?? ''));

            if (empty($message)) {
                http_response_code(400);
                echo json_encode(["status" => "error", "message" => "Message is required."]);
                exit;
            }

            $stmt = $conn->prepare("INSERT INTO support_tickets (tenant_id, subject, message, status) VALUES (?, ?, ?, 'Open')");
            $stmt->bind_param("sss", $tenant_id, $subject, $message);
            if ($stmt->execute()) {
                $ticket_id = $conn->insert_id;

                // Also insert initial message as first reply
                $rep = $conn->prepare("INSERT INTO support_ticket_replies (ticket_id, sender, message) VALUES (?, ?, ?)");
                $rep->bind_param("iss", $ticket_id, $tenant_id, $message);
                $rep->execute();

                // Queue in-app notification & email to admin profile email
                $admin_res = $conn->query("SELECT email FROM super_admins LIMIT 1");
                if ($admin_res && $row = $admin_res->fetch_assoc()) {
                    $admin_email = $row['email'];
                    if (!empty($admin_email)) {
                        $notif = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type) VALUES (?, ?, ?, ?, 'support')");
                        $title = "New Support Ticket #$ticket_id";
                        $notif_msg = "Tenant $tenant_id submitted a ticket: $subject";
                        $notif->bind_param("ssss", $tenant_id, $admin_email, $title, $notif_msg);
                        $notif->execute();
                        queueEmailNotification($conn, $tenant_id, $admin_email, $conn->insert_id, 'support');
                    }
                }

                echo json_encode(["status" => "success", "message" => "Support ticket created successfully.", "ticket_id" => $ticket_id]);
            } else {
                echo json_encode(["status" => "error", "message" => "Failed to create support ticket."]);
            }
            break;

        case 'get_ticket_history':
            $ticket_id = (int)($_GET['ticket_id'] ?? 0);
            if ($ticket_id <= 0) {
                echo json_encode(["status" => "error", "message" => "Valid Ticket ID required."]);
                exit;
            }

            $stmt = $conn->prepare("SELECT * FROM support_ticket_replies WHERE ticket_id = ? ORDER BY created_at ASC");
            $stmt->bind_param("i", $ticket_id);
            $stmt->execute();
            $res = $stmt->get_result();
            $replies = [];
            while ($row = $res->fetch_assoc()) {
                $replies[] = $row;
            }
            echo json_encode(["status" => "success", "data" => $replies]);
            break;

        case 'send_reply':
            $json = file_get_contents('php://input');
            $data = json_decode($json);

            $ticket_id = (int)($data->ticket_id ?? 0);
            $sender = trim((string)($data->sender ?? 'Admin'));
            $message = trim((string)($data->message ?? ''));

            if ($ticket_id <= 0 || empty($message)) {
                http_response_code(400);
                echo json_encode(["status" => "error", "message" => "Ticket ID and message are required."]);
                exit;
            }

            $stmt = $conn->prepare("INSERT INTO support_ticket_replies (ticket_id, sender, message) VALUES (?, ?, ?)");
            $stmt->bind_param("iss", $ticket_id, $sender, $message);
            if ($stmt->execute()) {
                // Fetch ticket info for notification
                $t_stmt = $conn->prepare("SELECT tenant_id, subject FROM support_tickets WHERE id = ? LIMIT 1");
                $t_stmt->bind_param("i", $ticket_id);
                $t_stmt->execute();
                $t_res = $t_stmt->get_result();
                if ($t_row = $t_res->fetch_assoc()) {
                    $tenant_id = $t_row['tenant_id'];
                    $subject = $t_row['subject'];

                    // Get tenant admin email for notification
                    $admin_email = '';
                    $tenant_lookup = $conn->prepare("SELECT contact_email, primary_email FROM tenants WHERE tenant_id = ? OR custom_domain = ? LIMIT 1");
                    if ($tenant_lookup) {
                        $tenant_lookup->bind_param("ss", $tenant_id, $tenant_id);
                        $tenant_lookup->execute();
                        $t_res = $tenant_lookup->get_result();
                        if ($t_row = $t_res->fetch_assoc()) {
                            $admin_email = !empty($t_row['contact_email']) ? $t_row['contact_email'] : (!empty($t_row['primary_email']) ? $t_row['primary_email'] : '');
                        }
                    }

                    if (filter_var($admin_email, FILTER_VALIDATE_EMAIL)) {
                        $notif = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type) VALUES (?, ?, ?, ?, 'support_reply')");
                        $title = "Support Reply on Ticket #$ticket_id";
                        $notif_msg = "$sender replied: $message";
                        $notif->bind_param("ssss", $tenant_id, $admin_email, $title, $notif_msg);
                        $notif->execute();
                        $notif_id = $conn->insert_id;
                        queueEmailNotification($conn, $tenant_id, $admin_email, $notif_id, 'support_reply');
                    } else {
                        error_log(
                            "Support reply notification skipped: no valid admin email for tenant " .
                            $tenant_id
                        );
                    }
                }

                echo json_encode(["status" => "success", "message" => "Reply sent successfully."]);
            } else {
                echo json_encode(["status" => "error", "message" => "Failed to send reply."]);
            }
            break;

        case 'update_status':
            $json = file_get_contents('php://input');
            $data = json_decode($json);

            $ticket_id = (int)($data->ticket_id ?? 0);
            $status = trim((string)($data->status ?? 'Open'));

            if ($ticket_id <= 0) {
                echo json_encode(["status" => "error", "message" => "Ticket ID required."]);
                exit;
            }

            $stmt = $conn->prepare("UPDATE support_tickets SET status = ? WHERE id = ?");
            $stmt->bind_param("si", $status, $ticket_id);
            if ($stmt->execute()) {
                echo json_encode(["status" => "success", "message" => "Ticket status updated."]);
            } else {
                echo json_encode(["status" => "error", "message" => "Failed to update ticket status."]);
            }
            break;

        default:
            echo json_encode(["status" => "error", "message" => "Invalid support action"]);
            break;
    }
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "System error: " . $e->getMessage()]);
}

$conn->close();
?>
