<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

try {
    require_once __DIR__ . '/db_config.php';
    require_once __DIR__ . '/staff_auth.php';
    require_once __DIR__ . '/billing_common.php';

    $staff = billingAuthTenant($conn, ['admin', 'cashier', 'waiter', 'kitchen']);
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        billingRespond(405, ['status' => 'error', 'message' => 'GET is required']);
    }

    $tenantId = (string)$staff['tenant_id'];
    $requestedTenant = trim((string)($_GET['tenant_id'] ?? ''));
    if ($requestedTenant !== '' && $requestedTenant !== $tenantId) {
        billingRespond(403, ['status' => 'error', 'message' => 'Tenant does not match the authenticated staff session']);
    }

    billingEnsureSchema($conn);
    $ordersStmt = $conn->prepare(
        'SELECT o.*, COALESCE(t.table_number, s.table_number, o.table_id, 1) AS table_number,
                s.status AS session_status
         FROM orders o
         LEFT JOIN restaurant_tables t
           ON t.id = o.table_id
          AND t.tenant_id COLLATE utf8mb4_general_ci =
              o.tenant_id COLLATE utf8mb4_general_ci
         LEFT JOIN dining_sessions s
           ON s.id = o.session_id
          AND s.tenant_id COLLATE utf8mb4_general_ci =
              o.tenant_id COLLATE utf8mb4_general_ci
         WHERE o.tenant_id COLLATE utf8mb4_general_ci =
               ? COLLATE utf8mb4_general_ci
         ORDER BY o.created_at DESC, o.id DESC'
    );
    $ordersStmt->bind_param('s', $tenantId);
    $ordersStmt->execute();
    $ordersResult = $ordersStmt->get_result();

    $itemsStmt = $conn->prepare(
        'SELECT oi.*
         FROM order_items oi
         INNER JOIN orders o ON o.id = oi.order_id
         WHERE o.tenant_id COLLATE utf8mb4_general_ci =
               ? COLLATE utf8mb4_general_ci
           AND oi.order_id = ?
         ORDER BY oi.id'
    );
    $orders = [];
    while ($order = $ordersResult->fetch_assoc()) {
        $orderId = (int)$order['id'];
        $itemsStmt->bind_param('si', $tenantId, $orderId);
        $itemsStmt->execute();
        $order['items'] = $itemsStmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $orders[] = $order;
    }
    $itemsStmt->close();
    $ordersStmt->close();

    billingRespond(200, ['status' => 'success', 'data' => $orders]);
} catch (Throwable $error) {
    error_log('Order list lookup failed: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'status' => 'error',
        'error' => 'Could not load restaurant orders',
        'message' => 'Could not load restaurant orders',
    ]);
}
?>
