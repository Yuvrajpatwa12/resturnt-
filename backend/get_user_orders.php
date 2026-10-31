<?php
/**
 * Return a customer's orders, including orders placed with a guest ID.
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';

if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Database connection failed",
    ]);
    exit;
}

$tenant_id = trim((string)($_GET['tenant_id'] ?? ''));
$user_id = trim((string)($_GET['user_id'] ?? ''));
$customer_email = trim((string)($_GET['customer_email'] ?? ''));
$guest_id = trim((string)($_GET['guest_id'] ?? ''));
$order_id_param = trim((string)($_GET['order_id'] ?? $_GET['order_ids'] ?? ''));

$order_ids = [];
if ($order_id_param !== '') {
    foreach (explode(',', $order_id_param) as $p) {
        $val = (int)trim($p);
        if ($val > 0) $order_ids[] = $val;
    }
}

if ($user_id === '') {
    $user_id = $customer_email !== '' ? $customer_email : $guest_id;
}

if ($tenant_id === '' || ($user_id === '' && $customer_email === '' && $guest_id === '' && empty($order_ids))) {
    http_response_code(400);
    echo json_encode([
        "status" => "error",
        "message" => "Missing tenant or user identification",
    ]);
    $conn->close();
    exit;
}

$id_clause = "";
if (!empty($order_ids)) {
    $id_clause = " OR o.id IN (" . implode(',', $order_ids) . ") ";
}

try {
    $orders_stmt = $conn->prepare(
        "SELECT o.*, COALESCE(t.table_number, o.table_id, 1) AS table_number
         FROM orders o
         LEFT JOIN restaurant_tables t
           ON t.id = o.table_id AND t.tenant_id = o.tenant_id
         WHERE o.tenant_id = ?
           AND (
             ( ? != '' AND (o.user_id = ? OR o.customer_email = ?) )
             OR ( ? != '' AND (o.user_id = ? OR o.customer_email = ?) )
             OR ( ? != '' AND (o.user_id = ? OR o.customer_email = ?) )
             $id_clause
           )
         ORDER BY o.created_at DESC, o.id DESC"
    );
    $orders_stmt->bind_param(
        "ssssssssss",
        $tenant_id,
        $user_id, $user_id, $user_id,
        $customer_email, $customer_email, $customer_email,
        $guest_id, $guest_id, $guest_id
    );
    $orders_stmt->execute();
    $orders_result = $orders_stmt->get_result();

    $items_stmt = $conn->prepare(
        "SELECT oi.*,
                COALESCE((
                    SELECT p.image_url
                    FROM products p
                    WHERE p.tenant_id = ?
                      AND (
                        (oi.product_id > 0 AND p.id = oi.product_id)
                        OR p.title = oi.product_name
                      )
                    LIMIT 1
                ), '') AS image_url
         FROM order_items oi
         WHERE oi.order_id = ?
         ORDER BY oi.id ASC"
    );

    $orders = [];
    $max_amount = 0.0;
    while ($order = $orders_result->fetch_assoc()) {
        $order_id = (int)$order['id'];
        $items_stmt->bind_param("si", $tenant_id, $order_id);
        $items_stmt->execute();
        $items_result = $items_stmt->get_result();
        $items = [];
        while ($item = $items_result->fetch_assoc()) {
            $items[] = $item;
        }

        $order['items'] = $items;
        if (empty($order['status']) || trim($order['status']) === '') {
            $order['status'] = 'Pending';
        }
        $max_amount = max($max_amount, (float)$order['total_amount']);
        $orders[] = $order;
    }

    echo json_encode([
        "status" => "success",
        "data" => $orders,
        "orders" => $orders,
        "total_count" => count($orders),
        "max_amount" => $max_amount,
    ]);
    $items_stmt->close();
    $orders_stmt->close();
} catch (Throwable $error) {
    error_log("Get user orders failed: " . $error->getMessage());
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Could not retrieve orders",
    ]);
}

$conn->close();
?>
