<?php
/**
 * get_user_orders.php
 * Returns all orders (Live + History) for a specific User ID or Email.
 */
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once 'db_config.php';

if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Database connection failed"]));
}

$tenant_id = $_GET['tenant_id'] ?? '';
$user_id = $_GET['user_id'] ?? ''; // Guest ID or Email

if (empty($tenant_id) || empty($user_id)) {
    echo json_encode(["status" => "error", "message" => "Missing identification"]);
    exit;
}

try {
    // Fetch ALL orders matching this user in this restaurant
    // Matching either user_id OR customer_email
    $sql = "SELECT o.*, t.table_number
            FROM orders o
            JOIN restaurant_tables t ON o.table_id = t.id
            WHERE o.tenant_id = ?
            AND (o.user_id = ? OR o.customer_email = ?)
            ORDER BY o.created_at DESC";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sss", $tenant_id, $user_id, $user_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $orders = [];
    while ($row = $result->fetch_assoc()) {
        $orders[] = $row;
    }

    echo json_encode([
        "status" => "success",
        "data" => $orders,
        "total_count" => count($orders)
    ]);

} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => "API Error: " . $e->getMessage()]);
}

$conn->close();
?>
