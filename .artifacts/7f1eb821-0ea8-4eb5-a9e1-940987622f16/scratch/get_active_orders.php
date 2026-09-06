<?php
/**
 * get_active_orders.php - MySQLi Version
 * Fetches orders and joins with restaurant_tables to provide table_number.
 */
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once 'db_config.php';

if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Database connection failed"]));
}

$tenant_id = $_GET['tenant_id'] ?? '';

if (empty($tenant_id)) {
    echo json_encode(["status" => "error", "message" => "Missing tenant_id"]);
    exit;
}

try {
    // Join orders with restaurant_tables to get the table_number
    $sql = "SELECT o.*, t.table_number
            FROM orders o
            JOIN restaurant_tables t ON o.table_id = t.id
            WHERE o.tenant_id = ? AND o.status NOT IN ('Completed', 'Cancelled')
            ORDER BY o.created_at DESC";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("s", $tenant_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $orders = [];
    while ($row = $result->fetch_assoc()) {
        // Also fetch items for each order
        $order_id = $row['id'];
        $items_res = $conn->query("SELECT * FROM order_items WHERE order_id = $order_id");
        $row['items'] = $items_res->fetch_all(MYSQLI_ASSOC);
        $orders[] = $row;
    }

    echo json_encode(["status" => "success", "data" => $orders]);

} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => "API Error: " . $e->getMessage()]);
}

$conn->close();
?>
