<?php
/**
 * place_order.php - Final Production Version
 * Fixes loop issues and adds strict error reporting.
 */

// 1. Error Reporting (Critical for Hostinger Debugging)
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';

if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "DB Connection Failed"]));
}

$json = file_get_contents('php://input');
$data = json_decode($json);

if (!$data || empty($data->tenant_id) || empty($data->table_number)) {
    echo json_encode(["status" => "error", "message" => "Invalid Data Received"]);
    exit;
}

$tenant_id = (string)$data->tenant_id;
$table_number = (int)$data->table_number;
$user_id = (string)($data->user_id ?? '');
$customer_email = (string)($data->customer_email ?? '');
$total_amount = (float)$data->total_amount;

try {
    $conn->begin_transaction();

    // 1. Resolve Table ID
    $t_stmt = $conn->prepare("SELECT id FROM restaurant_tables WHERE tenant_id = ? AND table_number = ? LIMIT 1");
    $t_stmt->bind_param("si", $tenant_id, $table_number);
    $t_stmt->execute();
    $t_res = $t_stmt->get_result();

    if ($t_row = $t_res->fetch_assoc()) {
        $table_id = $t_row['id'];
        $conn->query("UPDATE restaurant_tables SET status = 'Dining' WHERE id = $table_id");
    } else {
        $ins_t = $conn->prepare("INSERT INTO restaurant_tables (tenant_id, table_number, status) VALUES (?, ?, 'Dining')");
        $ins_t->bind_param("si", $tenant_id, $table_number);
        $ins_t->execute();
        $table_id = $conn->insert_id;
    }

    // 2. CHECK FOR ACTIVE DINING SESSION (Auto-Link)
    $session_id = null;
    $s_stmt = $conn->prepare("SELECT id FROM dining_sessions WHERE tenant_id = ? AND table_number = ? AND status = 'Open' LIMIT 1");
    $s_stmt->bind_param("si", $tenant_id, $table_number);
    $s_stmt->execute();
    if ($s_row = $s_stmt->get_result()->fetch_assoc()) {
        $session_id = $s_row['id'];
        // Update session timestamp to trigger "Delta Sync" for all devices
        $conn->query("UPDATE dining_sessions SET last_modified = CURRENT_TIMESTAMP WHERE id = $session_id");
    }

    // 3. Create Order
    $stmt = $conn->prepare("INSERT INTO orders (tenant_id, table_id, user_id, customer_email, total_amount, status, session_id) VALUES (?, ?, ?, ?, ?, 'Pending', ?)");
    $stmt->bind_param("sissdi", $tenant_id, $table_id, $user_id, $customer_email, $total_amount, $session_id);
    $stmt->execute();
    $order_id = $conn->insert_id;

    // 3. Save Items
    if (!empty($data->items)) {
        $item_stmt = $conn->prepare("INSERT INTO order_items (order_id, product_name, quantity, price_at_order) VALUES (?, ?, ?, ?)");
        $item_stmt->bind_param("isid", $order_id, $item_name, $item_qty, $item_prc);

        foreach ($data->items as $item) {
            $item_name = (string)$item->name;
            $item_qty = (int)$item->quantity;
            $item_prc = (float)$item->price;
            $item_stmt->execute();
        }
    }

    $conn->commit();

    // Trigger Notification after commit
    $notif_title = "Order Placed!";
    $notif_msg = "Your Order #$order_id is now pending. We'll start preparing it soon!";
    $target_uid = !empty($customer_email) ? $customer_email : $user_id;

    if (!empty($target_uid)) {
        $notif_ins = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type) VALUES (?, ?, ?, ?, 'order')");
        $notif_ins->bind_param("ssss", $tenant_id, $target_uid, $notif_title, $notif_msg);
        $notif_ins->execute();
    }

    echo json_encode([
        "status" => "success",
        "order_id" => (int)$order_id,
        "message" => "Order placed successfully"
    ]);

} catch (Exception $e) {
    if ($conn) $conn->rollback();
    echo json_encode(["status" => "error", "message" => "System Error: " . $e->getMessage()]);
}

$conn->close();
?>
