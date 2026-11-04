<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=UTF-8');
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
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        billingRespond(405, ['status' => 'error', 'message' => 'POST is required']);
    }
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) {
        billingRespond(400, ['status' => 'error', 'message' => 'Invalid JSON request']);
    }
    $sessionId = (int)($data['session_id'] ?? 0);
    $tableId = (int)($data['table_id'] ?? 0);
    $newStatus = trim((string)($data['status'] ?? ''));
    if ($newStatus !== 'ReadyForBilling' || (($sessionId > 0) === ($tableId > 0))) {
        billingRespond(400, ['status' => 'error', 'message' => 'Provide a session or table and status ReadyForBilling']);
    }

    $tenantId = (string)$staff['tenant_id'];
    if ($sessionId > 0) {
        $stmt = $conn->prepare('SELECT id, table_id, table_number, status FROM dining_sessions WHERE id = ? AND tenant_id = ? FOR UPDATE');
        $stmt->bind_param('is', $sessionId, $tenantId);
    } else {
        $stmt = $conn->prepare("SELECT s.id, s.table_id, s.table_number, s.status
            FROM dining_sessions s
            WHERE s.tenant_id = ? AND (s.table_id = ? OR
                (s.table_id IS NULL AND EXISTS (
                    SELECT 1 FROM restaurant_tables t WHERE t.id = ? AND t.tenant_id = s.tenant_id AND t.table_number = s.table_number
                )))
            ORDER BY CASE WHEN LOWER(s.status) NOT IN ('settled', 'closed') THEN 0 ELSE 1 END,
                     s.id DESC LIMIT 1 FOR UPDATE");
        $stmt->bind_param('sii', $tenantId, $tableId, $tableId);
    }
    $conn->begin_transaction();
    if ($sessionId > 0) {
        $sessionProbe = $conn->prepare(
            'SELECT table_id, table_number FROM dining_sessions
             WHERE id = ? AND tenant_id = ? LIMIT 1'
        );
        $sessionProbe->bind_param('is', $sessionId, $tenantId);
        $sessionProbe->execute();
        $sessionLocation = $sessionProbe->get_result()->fetch_assoc();
        $sessionProbe->close();
        if ($sessionLocation) {
            if (!empty($sessionLocation['table_id'])) {
                $tableLock = $conn->prepare(
                    'SELECT id FROM restaurant_tables WHERE id = ? AND tenant_id = ? FOR UPDATE'
                );
                $sessionTableId = (int)$sessionLocation['table_id'];
                $tableLock->bind_param('is', $sessionTableId, $tenantId);
            } else {
                $tableLock = $conn->prepare(
                    'SELECT id FROM restaurant_tables WHERE table_number = ? AND tenant_id = ? FOR UPDATE'
                );
                $sessionTableNumber = (int)$sessionLocation['table_number'];
                $tableLock->bind_param('is', $sessionTableNumber, $tenantId);
            }
        } else {
            $conn->rollback();
            billingRespond(404, ['status' => 'error', 'message' => 'No session was found for this table']);
        }
    } else {
        $tableLock = $conn->prepare(
            'SELECT id FROM restaurant_tables WHERE id = ? AND tenant_id = ? FOR UPDATE'
        );
        $tableLock->bind_param('is', $tableId, $tenantId);
    }
    $tableLock->execute();
    $tableLock->close();
    $stmt->execute();
    $session = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$session) {
        $conn->rollback();
        billingRespond(404, ['status' => 'error', 'message' => 'No session was found for this table']);
    }
    if (strtolower((string)$session['status']) === 'settled') {
        $conn->rollback();
        billingRespond(409, ['status' => 'error', 'message' => 'A settled session cannot be sent to billing']);
    }
    $resolvedSessionId = (int)$session['id'];
    $ordersStmt = $conn->prepare("SELECT COUNT(*) AS order_count FROM orders WHERE tenant_id = ? AND session_id = ? AND LOWER(status) <> 'settled'");
    $ordersStmt->bind_param('si', $tenantId, $resolvedSessionId);
    $ordersStmt->execute();
    $hasOrders = (int)$ordersStmt->get_result()->fetch_assoc()['order_count'] > 0;
    $ordersStmt->close();
    if (!$hasOrders) {
        $conn->rollback();
        billingRespond(409, ['status' => 'error', 'message' => 'This session has no active orders']);
    }
    $ordersStmt = $conn->prepare("SELECT id FROM orders
        WHERE tenant_id = ? AND session_id = ?
          AND LOWER(status) NOT IN ('settled', 'voided')
        ORDER BY id");
    $ordersStmt->bind_param('si', $tenantId, $resolvedSessionId);
    $ordersStmt->execute();
    $ordersResult = $ordersStmt->get_result();
    $orderIds = [];
    while ($order = $ordersResult->fetch_assoc()) {
        $orderIds[] = (int)$order['id'];
    }
    $ordersStmt->close();
    $bill = billingCalculateBill($conn, $tenantId, $orderIds, null, true);
    if ((float)$bill['grand_total'] <= 0) {
        $conn->rollback();
        billingRespond(409, [
            'status' => 'error',
            'message' => 'No Served or Completed items are ready to bill'
        ]);
    }

    $update = $conn->prepare("UPDATE dining_sessions SET status = 'ReadyForBilling', last_modified = CURRENT_TIMESTAMP
        WHERE id = ? AND tenant_id = ? AND status <> 'Settled'");
    $update->bind_param('is', $resolvedSessionId, $tenantId);
    $update->execute();
    $update->close();
    if (!empty($session['table_id'])) {
        $tableUpdate = $conn->prepare("UPDATE restaurant_tables
            SET status = 'ReadyForBilling' WHERE id = ? AND tenant_id = ?");
        $sessionTableId = (int)$session['table_id'];
        $tableUpdate->bind_param('is', $sessionTableId, $tenantId);
    } else {
        $tableUpdate = $conn->prepare("UPDATE restaurant_tables
            SET status = 'ReadyForBilling' WHERE table_number = ? AND tenant_id = ?");
        $sessionTableNumber = (int)$session['table_number'];
        $tableUpdate->bind_param('is', $sessionTableNumber, $tenantId);
    }
    $tableUpdate->execute();
    $tableUpdate->close();
    $conn->commit();
    billingRespond(200, ['status' => 'success', 'session_id' => $resolvedSessionId, 'session_status' => 'ReadyForBilling']);
} catch (BillingConfigurationException $error) {
    try { $conn->rollback(); } catch (Throwable $rollbackError) {}
    billingRespond(409, ['status' => 'error', 'message' => $error->getMessage()]);
} catch (Throwable $error) {
    try { $conn->rollback(); } catch (Throwable $ignored) {}
    error_log('Session status update failed: ' . $error->getMessage());
    billingRespond(500, ['status' => 'error', 'message' => 'Could not send this table to billing']);
}
?>
