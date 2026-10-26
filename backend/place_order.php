<?php
/**
 * place_order.php - Final Ultra-Robust Production Version with FCM Push Notifications
 */

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
require_once 'push_notifier.php';

if ($conn->connect_error) {
    echo json_encode(["status" => "error", "message" => "DB Connection Failed"]);
    exit;
}

$json = file_get_contents('php://input');
$data = json_decode($json);

$tenant_id = (!empty($data->tenant_id)) ? (string)$data->tenant_id : 'startups_main';
$table_number = (isset($data->table_number) && (int)$data->table_number > 0) ? (int)$data->table_number : 1;
$user_id = (!empty($data->user_id)) ? (string)$data->user_id : 'guest';
$customer_email = (!empty($data->customer_email)) ? (string)$data->customer_email : '';
$total_amount = (isset($data->total_amount)) ? (float)$data->total_amount : 0.00;

try {
    try {
        @mysqli_query($conn, "CREATE TABLE IF NOT EXISTS orders (
            id INT AUTO_INCREMENT PRIMARY KEY,
            tenant_id VARCHAR(100) NOT NULL,
            table_id INT DEFAULT NULL,
            user_id VARCHAR(100) DEFAULT '',
            customer_email VARCHAR(255) DEFAULT '',
            total_amount DECIMAL(10,2) DEFAULT 0.00,
            status VARCHAR(50) DEFAULT 'Pending',
            session_id INT DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )");
    } catch (Throwable $e) {}

    try {
        @mysqli_query($conn, "CREATE TABLE IF NOT EXISTS order_items (
            id INT AUTO_INCREMENT PRIMARY KEY,
            order_id INT NOT NULL,
            product_id INT DEFAULT 0,
            product_name VARCHAR(255) NOT NULL,
            quantity INT DEFAULT 1,
            notes TEXT DEFAULT NULL,
            price_at_order DECIMAL(10,2) DEFAULT 0.00,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )");
    } catch (Throwable $e) {}

    try { @mysqli_query($conn, "ALTER TABLE orders ADD COLUMN customer_email VARCHAR(255) DEFAULT ''"); } catch (Throwable $e) {}
    try { @mysqli_query($conn, "ALTER TABLE orders ADD COLUMN session_id INT DEFAULT NULL"); } catch (Throwable $e) {}
    try { @mysqli_query($conn, "ALTER TABLE order_items ADD COLUMN product_id INT DEFAULT 0"); } catch (Throwable $e) {}

    $conn->begin_transaction();

    // 1. Resolve Table ID
    $t_stmt = $conn->prepare("SELECT id FROM restaurant_tables WHERE tenant_id = ? AND table_number = ? LIMIT 1");
    $t_stmt->bind_param("si", $tenant_id, $table_number);
    $t_stmt->execute();
    $t_res = $t_stmt->get_result();

    $table_id = null;
    if ($t_row = $t_res->fetch_assoc()) {
        $table_id = (int)$t_row['id'];
        $table_update = $conn->prepare("UPDATE restaurant_tables SET status = 'Dining' WHERE id = ?");
        $table_update->bind_param("i", $table_id);
        $table_update->execute();
    } else {
        $ins_t = $conn->prepare("INSERT INTO restaurant_tables (tenant_id, table_number, status) VALUES (?, ?, 'Dining')");
        $ins_t->bind_param("si", $tenant_id, $table_number);
        $ins_t->execute();
        $table_id = (int)$conn->insert_id;
    }

    // 2. CHECK FOR ACTIVE DINING SESSION
    $session_id_val = 0;
    try {
        $s_stmt = $conn->prepare("SELECT id FROM dining_sessions WHERE tenant_id = ? AND table_number = ? AND status = 'Open' LIMIT 1");
        if ($s_stmt) {
            $s_stmt->bind_param("si", $tenant_id, $table_number);
            $s_stmt->execute();
            if ($s_row = $s_stmt->get_result()->fetch_assoc()) {
                $session_id_val = (int)$s_row['id'];
                $session_update = $conn->prepare("UPDATE dining_sessions SET last_modified = CURRENT_TIMESTAMP WHERE id = ?");
                $session_update->bind_param("i", $session_id_val);
                $session_update->execute();
            }
        }
    } catch (Exception $ex) {}

    // 3. Create Order
    $stmt = $conn->prepare("INSERT INTO orders (tenant_id, table_id, user_id, customer_email, total_amount, status, session_id, created_at) VALUES (?, ?, ?, ?, ?, 'Pending', ?, NOW())");
    $stmt->bind_param("sissdi", $tenant_id, $table_id, $user_id, $customer_email, $total_amount, $session_id_val);
    $stmt->execute();
    $order_id = (int)$conn->insert_id;
    if ($order_id <= 0) {
        throw new RuntimeException("Order record was not created");
    }

    // 4. Save Items (Matching exact order_items schema: order_id, product_id, product_name, quantity, price_at_order)
    if (!empty($data->items)) {
        $item_ins = $conn->prepare("INSERT INTO order_items (order_id, product_id, product_name, quantity, price_at_order) VALUES (?, ?, ?, ?, ?)");

        foreach ($data->items as $item) {
            $item_pid = (int)($item->product_id ?? $item->id ?? 0);
            $item_name = (string)($item->name ?? $item->product_name ?? 'Item');
            $item_qty = (int)($item->quantity ?? 1);
            $item_prc = (float)($item->price ?? $item->price_at_order ?? 0.00);

            $item_ins->bind_param("iisid", $order_id, $item_pid, $item_name, $item_qty, $item_prc);
            $item_ins->execute();
        }
    }

    $conn->commit();

    // 5. Trigger Order Notification & FCM Push
    $target_uid = !empty($customer_email) ? $customer_email : $user_id;
    if (!empty($target_uid) && $target_uid !== 'guest') {
        try {
            $notif_title = "Order Placed!";
            $notif_msg = "Your Order #$order_id has been received and is pending preparation.";

            $notif_ins = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type) VALUES (?, ?, ?, ?, 'order')");
            $notif_ins->bind_param("ssss", $tenant_id, $target_uid, $notif_title, $notif_msg);
            $notif_ins->execute();

            notifyUser($target_uid, $tenant_id, $notif_title, $notif_msg, 'order');
        } catch (Throwable $notification_error) {
            error_log("Order #$order_id was saved, but notification delivery failed: " . $notification_error->getMessage());
        }
    }

    echo json_encode([
        "status" => "success",
        "order_id" => (int)$order_id,
        "message" => "Order placed successfully"
    ]);

} catch (Exception $e) {
    if ($conn) {
        try { $conn->rollback(); } catch(Exception $ex) {}
    }
    echo json_encode(["status" => "error", "message" => "System Error: " . $e->getMessage()]);
}

if ($conn) {
    $conn->close();
}
?>
