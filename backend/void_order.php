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
function voidOrderRespond($status, $payload) {
    http_response_code($status);
    echo json_encode($payload);
    exit;
}
require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/staff_auth.php';
require_once __DIR__ . '/billing_common.php';
require_once __DIR__ . '/financial_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    voidOrderRespond(405, ['status' => 'error', 'message' => 'POST is required']);
}
$auth = requireAuth($conn, ['super_admin']);
$staff = isset($auth['user']) && is_array($auth['user']) ? $auth['user'] : [];
if (trim((string)($staff['tenant_id'] ?? '')) === '' || (int)($staff['id'] ?? 0) <= 0) {
    voidOrderRespond(401, ['status' => 'error', 'message' => 'Authenticated staff identity is incomplete']);
}
financialEnsureSchema($conn);
$data = json_decode(file_get_contents('php://input'), true);
$orderIdValue = $data['order_id'] ?? 0;
$orderId = is_scalar($orderIdValue) ? (int)$orderIdValue : 0;
$reasonValue = $data['reason'] ?? '';
$reason = is_string($reasonValue) ? trim($reasonValue) : '';
if ($orderId <= 0 || $reason === '' || strlen($reason) > 2000) {
    voidOrderRespond(400, ['status' => 'error', 'message' => 'A valid order_id and void reason are required']);
}
$tenantId = (string)$staff['tenant_id'];
$staffId = (int)$staff['id'];
try {
    $conn->begin_transaction();
    $orderProbe = $conn->prepare(
        'SELECT table_id, session_id FROM orders
         WHERE id = ? AND tenant_id = ? LIMIT 1'
    );
    $orderProbe->bind_param('is', $orderId, $tenantId);
    $orderProbe->execute();
    $orderLocation = $orderProbe->get_result()->fetch_assoc();
    $orderProbe->close();
    if (!$orderLocation) {
        $conn->rollback();
        voidOrderRespond(404, ['status' => 'error', 'message' => 'Order was not found for this tenant']);
    }

    $sessionId = (int)($orderLocation['session_id'] ?? 0);
    $sessionRow = null;
    if (!empty($orderLocation['table_id'])) {
        $tableLock = $conn->prepare(
            'SELECT id FROM restaurant_tables WHERE id = ? AND tenant_id = ? FOR UPDATE'
        );
        $orderTableId = (int)$orderLocation['table_id'];
        $tableLock->bind_param('is', $orderTableId, $tenantId);
    } elseif ($sessionId > 0) {
        $sessionProbe = $conn->prepare(
            'SELECT table_id, table_number FROM dining_sessions
             WHERE id = ? AND tenant_id = ? LIMIT 1'
        );
        $sessionProbe->bind_param('is', $sessionId, $tenantId);
        $sessionProbe->execute();
        $sessionLocation = $sessionProbe->get_result()->fetch_assoc();
        $sessionProbe->close();
        if ($sessionLocation && !empty($sessionLocation['table_id'])) {
            $tableLock = $conn->prepare(
                'SELECT id FROM restaurant_tables WHERE id = ? AND tenant_id = ? FOR UPDATE'
            );
            $sessionTableId = (int)$sessionLocation['table_id'];
            $tableLock->bind_param('is', $sessionTableId, $tenantId);
        } elseif ($sessionLocation) {
            $tableLock = $conn->prepare(
                'SELECT id FROM restaurant_tables WHERE table_number = ? AND tenant_id = ? FOR UPDATE'
            );
            $sessionTableNumber = (int)$sessionLocation['table_number'];
            $tableLock->bind_param('is', $sessionTableNumber, $tenantId);
        }
    }
    if (isset($tableLock)) {
        $tableLock->execute();
        $tableLock->close();
    }
    if ($sessionId > 0) {
        $sessionLookup = $conn->prepare(
            'SELECT table_id, table_number FROM dining_sessions
             WHERE id = ? AND tenant_id = ? LIMIT 1 FOR UPDATE'
        );
        $sessionLookup->bind_param('is', $sessionId, $tenantId);
        $sessionLookup->execute();
        $sessionRow = $sessionLookup->get_result()->fetch_assoc();
        $sessionLookup->close();
    }
    $orderStmt = $conn->prepare(
        'SELECT id, total_amount, status, session_id FROM orders
         WHERE id = ? AND tenant_id = ? LIMIT 1 FOR UPDATE'
    );
    $orderStmt->bind_param('is', $orderId, $tenantId);
    $orderStmt->execute();
    $order = $orderStmt->get_result()->fetch_assoc();
    $orderStmt->close();
    if (!$order) {
        $conn->rollback();
        voidOrderRespond(404, ['status' => 'error', 'message' => 'Order was not found for this tenant']);
    }
    if (strtolower((string)$order['status']) === 'voided') {
        $conn->rollback();
        voidOrderRespond(409, ['status' => 'error', 'message' => 'This order has already been voided']);
    }
    if (strtolower((string)$order['status']) === 'settled') {
        $conn->rollback();
        voidOrderRespond(409, ['status' => 'error', 'message' => 'Settled orders cannot be voided; issue a refund instead']);
    }
    $paymentCheck = $conn->prepare(
        "SELECT COUNT(*) AS payment_count
         FROM payment_orders po
         INNER JOIN payments p ON p.id = po.payment_id
         WHERE po.order_id = ? AND p.tenant_id = ? AND p.status = 'Completed'"
    );
    $paymentCheck->bind_param('is', $orderId, $tenantId);
    $paymentCheck->execute();
    $hasPayments = (int)$paymentCheck->get_result()->fetch_assoc()['payment_count'] > 0;
    $paymentCheck->close();
    $directPaymentCheck = $conn->prepare(
        "SELECT COUNT(*) AS payment_count FROM payments
         WHERE tenant_id = ? AND order_id = ? AND status = 'Completed'"
    );
    $directPaymentCheck->bind_param('si', $tenantId, $orderId);
    $directPaymentCheck->execute();
    $hasPayments = $hasPayments ||
        (int)$directPaymentCheck->get_result()->fetch_assoc()['payment_count'] > 0;
    $directPaymentCheck->close();
    if ($hasPayments) {
        $conn->rollback();
        voidOrderRespond(409, ['status' => 'error', 'message' => 'Orders linked to a payment cannot be voided; issue a refund instead']);
    }

    $audit = $conn->prepare(
        'INSERT INTO order_voids (order_id, tenant_id, staff_id, reason, original_amount)
         VALUES (?, ?, ?, ?, ?)'
    );
    $originalAmount = number_format((float)$order['total_amount'], 2, '.', '');
    $audit->bind_param('sisss', $orderId, $tenantId, $staffId, $reason, $originalAmount);
    $audit->execute();
    $audit->close();

    $void = $conn->prepare(
        "UPDATE orders SET status = 'Voided' WHERE id = ? AND tenant_id = ?"
    );
    $void->bind_param('is', $orderId, $tenantId);
    $void->execute();
    if ($void->affected_rows !== 1) {
        throw new RuntimeException('Order status was not updated');
    }
    $void->close();

    if ($sessionId > 0) {
        $remaining = $conn->prepare(
            "SELECT COUNT(*) AS order_count FROM orders
             WHERE tenant_id = ? AND session_id = ? AND LOWER(status) NOT IN ('settled', 'voided')"
        );
        $remaining->bind_param('si', $tenantId, $sessionId);
        $remaining->execute();
        $remainingCount = (int)$remaining->get_result()->fetch_assoc()['order_count'];
        $remaining->close();
        $nextSessionStatus = $remainingCount === 0 ? 'Closed' : 'Open';
        $nextTableStatus = $remainingCount === 0 ? 'Available' : 'Dining';
        $sessionUpdate = $conn->prepare(
            'UPDATE dining_sessions SET status = ?, last_modified = CURRENT_TIMESTAMP
             WHERE id = ? AND tenant_id = ?'
        );
        $sessionUpdate->bind_param('sis', $nextSessionStatus, $sessionId, $tenantId);
        $sessionUpdate->execute();
        $sessionUpdate->close();
        if ($sessionRow) {
            if (!empty($sessionRow['table_id'])) {
                $tableUpdate = $conn->prepare(
                    'UPDATE restaurant_tables SET status = ? WHERE id = ? AND tenant_id = ?'
                );
                $sessionTableId = (int)$sessionRow['table_id'];
                $tableUpdate->bind_param('sis', $nextTableStatus, $sessionTableId, $tenantId);
            } else {
                $tableUpdate = $conn->prepare(
                    'UPDATE restaurant_tables SET status = ? WHERE table_number = ? AND tenant_id = ?'
                );
                $sessionTableNumber = (int)$sessionRow['table_number'];
                $tableUpdate->bind_param('sis', $nextTableStatus, $sessionTableNumber, $tenantId);
            }
            $tableUpdate->execute();
            $tableUpdate->close();
        }
    }
    $conn->commit();
    voidOrderRespond(200, [
        'status' => 'success',
        'order_id' => $orderId,
        'order_status' => 'Voided',
        'original_amount' => $originalAmount,
        'message' => 'Order voided and audit reason recorded'
    ]);
} catch (Throwable $error) {
    try { $conn->rollback(); } catch (Throwable $ignored) {}
    error_log('Order void failed: ' . $error->getMessage());
    voidOrderRespond(500, ['status' => 'error', 'message' => 'Could not void this order']);
}
?>
