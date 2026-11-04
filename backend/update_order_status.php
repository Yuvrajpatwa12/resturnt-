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
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        billingRespond(405, ['status' => 'error', 'message' => 'POST is required']);
    }
    $auth = requireAuth($conn, ['admin', 'cashier', 'waiter', 'kitchen']);
    $staff = isset($auth['user']) && is_array($auth['user']) ? $auth['user'] : [];
    $tenantId = trim((string)($staff['tenant_id'] ?? ''));
    $orderId = (int)($_POST['order_id'] ?? 0);
    $data = json_decode(file_get_contents('php://input'), true);
    if (is_array($data)) {
        $orderId = (int)($data['order_id'] ?? $orderId);
        $newStatus = trim((string)($data['new_status'] ?? ''));
    } else {
        $newStatus = '';
    }
    if ($tenantId === '' || $orderId <= 0 ||
        !in_array($newStatus, [
            'Pending',
            'Approved',
            'Preparing',
            'Ready',
            'Served',
            'Completed',
            'Cancelled',
            'OnWay',
        ], true)) {
        billingRespond(400, ['status' => 'error', 'message' => 'Provide a valid order_id and supported order status']);
    }

    billingEnsureSchema($conn);
    $conn->begin_transaction();
    $orderProbe = $conn->prepare(
        'SELECT table_id, session_id FROM orders
         WHERE id = ? AND tenant_id = ? LIMIT 1'
    );
    $orderProbe->bind_param('is', $orderId, $tenantId);
    $orderProbe->execute();
    $location = $orderProbe->get_result()->fetch_assoc();
    $orderProbe->close();
    if (!$location) {
        $conn->rollback();
        billingRespond(404, ['status' => 'error', 'message' => 'Order was not found for this restaurant']);
    }

    $sessionId = (int)($location['session_id'] ?? 0);
    $session = null;
    if (!empty($location['table_id'])) {
        $tableLock = $conn->prepare(
            'SELECT id FROM restaurant_tables WHERE id = ? AND tenant_id = ? FOR UPDATE'
        );
        $tableId = (int)$location['table_id'];
        $tableLock->bind_param('is', $tableId, $tenantId);
        $tableLock->execute();
        $table = $tableLock->get_result()->fetch_assoc();
        $tableLock->close();
        if (!$table) {
            $conn->rollback();
            billingRespond(404, ['status' => 'error', 'message' => 'Restaurant table was not found']);
        }
    } elseif ($sessionId > 0) {
        $sessionProbe = $conn->prepare(
            'SELECT table_id, table_number FROM dining_sessions
             WHERE id = ? AND tenant_id = ? LIMIT 1'
        );
        $sessionProbe->bind_param('is', $sessionId, $tenantId);
        $sessionProbe->execute();
        $sessionLocation = $sessionProbe->get_result()->fetch_assoc();
        $sessionProbe->close();
        if (!$sessionLocation) {
            $conn->rollback();
            billingRespond(404, ['status' => 'error', 'message' => 'Dining session was not found']);
        }
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
        $tableLock->execute();
        $table = $tableLock->get_result()->fetch_assoc();
        $tableLock->close();
        if (!$table) {
            $conn->rollback();
            billingRespond(404, ['status' => 'error', 'message' => 'Restaurant table was not found']);
        }
    }
    if ($sessionId > 0) {
        $sessionStmt = $conn->prepare(
            'SELECT id, table_id, table_number, status FROM dining_sessions
             WHERE id = ? AND tenant_id = ? LIMIT 1 FOR UPDATE'
        );
        $sessionStmt->bind_param('is', $sessionId, $tenantId);
        $sessionStmt->execute();
        $session = $sessionStmt->get_result()->fetch_assoc();
        $sessionStmt->close();
        if (!$session) {
            $conn->rollback();
            billingRespond(404, ['status' => 'error', 'message' => 'Dining session was not found']);
        }
    }
    $orderStmt = $conn->prepare(
        'SELECT id, session_id, status FROM orders
         WHERE id = ? AND tenant_id = ? LIMIT 1 FOR UPDATE'
    );
    $orderStmt->bind_param('is', $orderId, $tenantId);
    $orderStmt->execute();
    $order = $orderStmt->get_result()->fetch_assoc();
    $orderStmt->close();
    if (!$order) {
        $conn->rollback();
        billingRespond(404, ['status' => 'error', 'message' => 'Order was not found for this restaurant']);
    }
    if ((int)($order['session_id'] ?? 0) !== $sessionId) {
        $conn->rollback();
        billingRespond(409, ['status' => 'error', 'message' => 'Order session changed; reload and retry']);
    }
    if (in_array(strtolower((string)$order['status']), ['settled', 'voided'], true)) {
        $conn->rollback();
        billingRespond(409, ['status' => 'error', 'message' => 'Settled or voided orders cannot be changed']);
    }
    if ($session && in_array(strtolower((string)$session['status']), ['settled', 'closed'], true)) {
        $conn->rollback();
        billingRespond(409, ['status' => 'error', 'message' => 'Settled or closed sessions cannot be changed']);
    }

    $updateItems = $conn->prepare(
        'UPDATE order_items oi
         LEFT JOIN payment_order_items poi ON poi.order_item_id = oi.id
         SET oi.status = ?
         WHERE oi.order_id = ? AND poi.order_item_id IS NULL'
    );
    $updateItems->bind_param('si', $newStatus, $orderId);
    $updateItems->execute();
    $updateItems->close();

    $updateOrder = $conn->prepare('UPDATE orders SET status = ? WHERE id = ? AND tenant_id = ?');
    $updateOrder->bind_param('sis', $newStatus, $orderId, $tenantId);
    $updateOrder->execute();
    $updateOrder->close();

    if (strtolower($newStatus) === 'cancelled' && $session) {
        $activeOrders = $conn->prepare(
            "SELECT COUNT(*) AS order_count FROM orders
             WHERE tenant_id = ? AND session_id = ?
               AND LOWER(status) NOT IN ('settled', 'voided', 'cancelled', 'canceled')"
        );
        $activeOrders->bind_param('si', $tenantId, $sessionId);
        $activeOrders->execute();
        $remainingOrderCount = (int)$activeOrders->get_result()
            ->fetch_assoc()['order_count'];
        $activeOrders->close();
        if ($remainingOrderCount === 0) {
            $closeSession = $conn->prepare(
                "UPDATE dining_sessions SET status = 'Closed',
                    last_modified = CURRENT_TIMESTAMP
                 WHERE id = ? AND tenant_id = ?"
            );
            $closeSession->bind_param('is', $sessionId, $tenantId);
            $closeSession->execute();
            $closeSession->close();
            if (!empty($session['table_id'])) {
                $tableUpdate = $conn->prepare(
                    "UPDATE restaurant_tables SET status = 'Available'
                     WHERE id = ? AND tenant_id = ?"
                );
                $sessionTableId = (int)$session['table_id'];
                $tableUpdate->bind_param('is', $sessionTableId, $tenantId);
            } else {
                $tableUpdate = $conn->prepare(
                    "UPDATE restaurant_tables SET status = 'Available'
                     WHERE table_number = ? AND tenant_id = ?"
                );
                $sessionTableNumber = (int)$session['table_number'];
                $tableUpdate->bind_param('is', $sessionTableNumber, $tenantId);
            }
            $tableUpdate->execute();
            $tableUpdate->close();
        }
    }
    $conn->commit();

    billingRespond(200, [
        'status' => 'success',
        'order_id' => $orderId,
        'order_status' => $newStatus,
        'message' => 'Order and its unbilled items were updated'
    ]);
} catch (Throwable $error) {
    try { $conn->rollback(); } catch (Throwable $ignored) {}
    error_log('Order status update failed: ' . $error->getMessage());
    billingRespond(500, ['status' => 'error', 'message' => 'Could not update this order']);
}
?>
