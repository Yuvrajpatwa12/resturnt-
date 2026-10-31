<?php
/**
 * get_ticket_history.php - Standalone & Backward-Compatible Support Ticket History Endpoint
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
    $_GET['action'] = 'get_ticket_history';
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

$ticket_id = intval($_GET['ticket_id'] ?? 0);

try {
    // Ensure tables exist
    @$conn->query("CREATE TABLE IF NOT EXISTS support_ticket_replies (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ticket_id INT NOT NULL,
        sender VARCHAR(100) DEFAULT 'Tenant',
        sender_type VARCHAR(50) DEFAULT 'Tenant',
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    @$conn->query("CREATE TABLE IF NOT EXISTS ticket_replies (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ticket_id INT NOT NULL,
        sender_type VARCHAR(20) DEFAULT 'Tenant',
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    // Primary Query: Fetch from support_ticket_replies
    $stmt = $conn->prepare("SELECT id, ticket_id, COALESCE(NULLIF(sender_type, ''), sender, 'Tenant') AS sender_type, COALESCE(NULLIF(sender, ''), sender_type, 'Tenant') AS sender, message, created_at FROM support_ticket_replies WHERE ticket_id = ? ORDER BY id ASC");
    $stmt->bind_param("i", $ticket_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $replies = [];
    while ($row = $result->fetch_assoc()) {
        $replies[] = $row;
    }

    // Fallback Query: Check ticket_replies if primary table was empty
    if (empty($replies)) {
        $stmt2 = $conn->prepare("SELECT id, ticket_id, sender_type, sender_type AS sender, message, created_at FROM ticket_replies WHERE ticket_id = ? ORDER BY id ASC");
        $stmt2->bind_param("i", $ticket_id);
        $stmt2->execute();
        $res2 = $stmt2->get_result();
        while ($row2 = $res2->fetch_assoc()) {
            $replies[] = $row2;
        }
    }

    echo json_encode(["status" => "success", "data" => $replies]);
} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage(), "data" => []]);
}
?>
