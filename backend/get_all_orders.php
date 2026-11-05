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

$numberingTransactionOpen = false;

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
    $numberColumn = $conn->query(
        "SHOW COLUMNS FROM orders LIKE 'tenant_order_number'"
    );
    if ($numberColumn->num_rows === 0) {
        $conn->query(
            'ALTER TABLE orders ADD COLUMN tenant_order_number INT UNSIGNED DEFAULT NULL'
        );
    }
    $numberIndex = $conn->query(
        "SHOW INDEX FROM orders WHERE Key_name = 'uniq_tenant_order_number'"
    );
    if ($numberIndex->num_rows === 0) {
        $conn->query(
            'ALTER TABLE orders ADD UNIQUE KEY uniq_tenant_order_number (tenant_id, tenant_order_number)'
        );
    }
    $conn->query("CREATE TABLE IF NOT EXISTS tenant_order_counters (
        tenant_id VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL PRIMARY KEY,
        last_number INT UNSIGNED NOT NULL DEFAULT 0,
        initialized TINYINT(1) NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

    $conn->begin_transaction();
    $numberingTransactionOpen = true;
    $counterInsert = $conn->prepare(
        'INSERT IGNORE INTO tenant_order_counters (tenant_id, last_number, initialized)
         VALUES (?, 0, 0)'
    );
    $counterInsert->bind_param('s', $tenantId);
    $counterInsert->execute();
    $counterInsert->close();

    $counterStmt = $conn->prepare(
        'SELECT last_number, initialized FROM tenant_order_counters
         WHERE tenant_id = ? LIMIT 1 FOR UPDATE'
    );
    $counterStmt->bind_param('s', $tenantId);
    $counterStmt->execute();
    $counter = $counterStmt->get_result()->fetch_assoc();
    $counterStmt->close();
    if (!$counter) {
        throw new RuntimeException('Could not initialize restaurant order numbers');
    }

    if ((int)$counter['initialized'] !== 1) {
        $legacyOrders = $conn->prepare(
            'SELECT id FROM orders WHERE tenant_id = ?
             ORDER BY created_at ASC, id ASC FOR UPDATE'
        );
        $legacyOrders->bind_param('s', $tenantId);
        $legacyOrders->execute();
        $legacyResult = $legacyOrders->get_result();
        $updateOrder = $conn->prepare(
            'UPDATE orders SET tenant_order_number = ?
             WHERE id = ? AND tenant_id = ?'
        );
        $lastNumber = 0;
        while ($legacyOrder = $legacyResult->fetch_assoc()) {
            $lastNumber++;
            $orderId = (int)$legacyOrder['id'];
            $updateOrder->bind_param('iis', $lastNumber, $orderId, $tenantId);
            $updateOrder->execute();
        }
        $updateOrder->close();
        $legacyOrders->close();

        $initializeCounter = $conn->prepare(
            'UPDATE tenant_order_counters
             SET last_number = ?, initialized = 1
             WHERE tenant_id = ?'
        );
        $initializeCounter->bind_param('is', $lastNumber, $tenantId);
        $initializeCounter->execute();
        $initializeCounter->close();
    }
    $conn->commit();
    $numberingTransactionOpen = false;

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
    if ($numberingTransactionOpen && isset($conn) && $conn instanceof mysqli) {
        try {
            $conn->rollback();
        } catch (Throwable $rollbackError) {
            error_log('Order list transaction rollback failed: ' . $rollbackError->getMessage());
        }
    }
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
