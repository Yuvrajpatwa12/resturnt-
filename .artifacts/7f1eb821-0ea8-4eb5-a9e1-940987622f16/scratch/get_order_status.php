<?php
/**
 * get_order_status.php - MySQLi Version
 * Fetches the current status of a specific order.
 */
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once 'db_config.php';

if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Database connection failed"]));
}

$order_id = $_GET['order_id'] ?? 0;

if (empty($order_id)) {
    echo json_encode(["status" => "error", "message" => "Missing order_id"]);
    exit;
}

try {
    $stmt = $conn->prepare("SELECT status FROM orders WHERE id = ? LIMIT 1");
    $stmt->bind_param("i", $order_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($row = $result->fetch_assoc()) {
        echo json_encode([
            "status" => "success",
            "order_status" => $row['status']
        ]);
    } else {
        echo json_encode([
            "status" => "error",
            "message" => "Order not found"
        ]);
    }

} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => "API Error: " . $e->getMessage()]);
}

$conn->close();
?>
