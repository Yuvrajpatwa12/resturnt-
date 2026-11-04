<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}
require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/staff_auth.php';
require_once __DIR__ . '/billing_common.php';

try {
    $staff = billingAuthTenant($conn, ['admin', 'cashier', 'waiter']);
    billingEnsureSchema($conn);
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        billingRespond(405, ['status' => 'error', 'message' => 'GET is required']);
    }
    $tenantId = (string)$staff['tenant_id'];
    $sessionId = filter_input(INPUT_GET, 'session_id', FILTER_VALIDATE_INT) ?: 0;
    $tableId = filter_input(INPUT_GET, 'table_id', FILTER_VALIDATE_INT) ?: 0;
    if (($sessionId > 0) === ($tableId > 0)) {
        billingRespond(400, ['status' => 'error', 'message' => 'Provide exactly one of session_id or table_id']);
    }

    if ($sessionId > 0) {
        $sessionStmt = $conn->prepare('SELECT id, table_id, table_number, status FROM dining_sessions WHERE id = ? AND tenant_id = ? LIMIT 1');
        $sessionStmt->bind_param('is', $sessionId, $tenantId);
    } else {
        $sessionStmt = $conn->prepare("SELECT s.id, s.table_id, s.table_number, s.status
            FROM dining_sessions s
            WHERE s.tenant_id = ? AND (s.table_id = ? OR
                (s.table_id IS NULL AND EXISTS (
                    SELECT 1 FROM restaurant_tables t
                    WHERE t.id = ? AND t.tenant_id = s.tenant_id AND t.table_number = s.table_number
                )))
            ORDER BY CASE WHEN LOWER(s.status) NOT IN ('settled', 'closed') THEN 0 ELSE 1 END,
                     s.id DESC LIMIT 1");
        $sessionStmt->bind_param('sii', $tenantId, $tableId, $tableId);
    }
    $sessionStmt->execute();
    $session = $sessionStmt->get_result()->fetch_assoc();
    $sessionStmt->close();
    if (!$session) {
        billingRespond(404, ['status' => 'error', 'message' => 'No dining session was found for this table']);
    }

    $ordersStmt = $conn->prepare("SELECT id FROM orders
        WHERE tenant_id = ? AND session_id = ?
          AND LOWER(status) NOT IN ('settled', 'voided')
        ORDER BY id");
    $sessionId = (int)$session['id'];
    $ordersStmt->bind_param('si', $tenantId, $sessionId);
    $ordersStmt->execute();
    $orderResult = $ordersStmt->get_result();
    $orderIds = [];
    while ($order = $orderResult->fetch_assoc()) {
        $orderIds[] = (int)$order['id'];
    }
    $ordersStmt->close();

    $bill = billingCalculateBill($conn, $tenantId, $orderIds);
    billingRespond(200, [
        'status' => 'success',
        'session_id' => $sessionId,
        'table_id' => $session['table_id'] === null ? null : (int)$session['table_id'],
        'table_number' => (int)$session['table_number'],
        'session_status' => (string)$session['status'],
        'order_ids' => $orderIds,
        'subtotal' => $bill['subtotal'],
        'tax' => $bill['tax'],
        'service_charge' => $bill['service_charge'],
        'grand_total' => $bill['grand_total'],
        'rates' => $bill['rates'],
        'items' => $bill['items'],
        'unbilled_items' => $bill['unbilled_items'],
        'previously_billed_items' => $bill['previously_billed_items'],
    ]);
} catch (BillingConfigurationException $error) {
    error_log('Session bill configuration error: ' . $error->getMessage());
    billingRespond(409, ['status' => 'error', 'message' => $error->getMessage()]);
} catch (Throwable $error) {
    error_log('Session bill lookup failed: ' . $error->getMessage());
    billingRespond(500, ['status' => 'error', 'message' => 'Could not load the session bill']);
}
?>
