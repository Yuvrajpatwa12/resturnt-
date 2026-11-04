
<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

function settleBillRespond($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload);
    exit;
}

function settleBillValue($sources, $keys) {
    foreach ($sources as $source) {
        if (!is_array($source)) continue;
        foreach ($keys as $key) {
            if (isset($source[$key]) && $source[$key] !== '') return $source[$key];
        }
    }
    return null;
}

function settleBillCents($value) {
    $value = trim((string)$value);
    if (!preg_match('/^(\d{1,10})(?:\.(\d{1,2}))?$/', $value, $matches)) return null;
    $whole = (int)$matches[1];
    $fraction = isset($matches[2]) ? str_pad($matches[2], 2, '0') : '00';
    return ($whole * 100) + (int)$fraction;
}

function settleBillExistingPayment($conn, $tenantId, $key) {
    $keys = [$key];
    for ($index = 1; $index < 20; $index++) {
        $keys[] = $key . '.' . $index;
    }
    $placeholders = implode(',', array_fill(0, count($keys), '?'));
    $stmt = $conn->prepare("SELECT id, amount, method, status, order_id, session_id
        FROM payments WHERE tenant_id = ? AND idempotency_key IN ($placeholders)
        ORDER BY id FOR UPDATE");
    $params = array_merge([$tenantId], $keys);
    settleBillBindParams($stmt, 's' . str_repeat('s', count($keys)), $params);
    $stmt->execute();
    $payments = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return $payments;
}

function settleBillReplayResponse($payments) {
    $recordedPayments = [];
    $amountCents = 0;
    foreach ($payments as $payment) {
        $partCents = settleBillCents($payment['amount']);
        if ($partCents === null) {
            throw new RuntimeException('Stored payment amount is invalid');
        }
        $amountCents += $partCents;
        $recordedPayments[] = [
            'payment_id' => (int)$payment['id'],
            'amount' => number_format($partCents / 100, 2, '.', ''),
            'method' => (string)$payment['method'],
            'payment_status' => (string)$payment['status'],
        ];
    }
    $primaryPayment = $payments[0];
    return [
        'status' => 'success',
        'message' => 'This bill was already settled',
        'payment_id' => (int)$primaryPayment['id'],
        'amount' => number_format($amountCents / 100, 2, '.', ''),
        'method' => count($payments) === 1 ? (string)$primaryPayment['method'] : null,
        'payment_status' => (string)$primaryPayment['status'],
        'order_id' => $primaryPayment['order_id'] === null ? null : (int)$primaryPayment['order_id'],
        'session_id' => $primaryPayment['session_id'] === null ? null : (int)$primaryPayment['session_id'],
        'payments' => $recordedPayments,
        'idempotent_replay' => true,
    ];
}

function settleBillBindParams($stmt, $types, &$params) {
    $bindings = [$types];
    foreach ($params as $index => &$value) {
        $bindings[] = &$value;
    }
    return call_user_func_array([$stmt, 'bind_param'], $bindings);
}

require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/billing_common.php';
if (is_file(__DIR__ . '/staff_auth.php')) {
    require_once __DIR__ . '/staff_auth.php';
}
if (!isset($conn) || $conn->connect_error) {
    settleBillRespond(500, ["status" => "error", "message" => "Database connection failed"]);
}
if (!function_exists('requireAuth')) {
    error_log("settle_bill.php requires requireAuth() from db_config.php");
    settleBillRespond(500, ["status" => "error", "message" => "Staff authentication is not configured"]);
}

$auth = requireAuth($conn, ['admin', 'cashier']);
$authData = is_array($auth) ? $auth : [];
$authUser = isset($authData['user']) && is_array($authData['user'])
    ? $authData['user']
    : $authData;
$sessionData = isset($_SESSION) && is_array($_SESSION) ? $_SESSION : [];
$sessionUser = isset($sessionData['staff']) && is_array($sessionData['staff'])
    ? $sessionData['staff']
    : [];
$sources = [$authUser, $sessionUser, $sessionData];

$role = strtolower(trim((string)(settleBillValue($sources, ['role', 'staff_role']) ?? '')));
if (!in_array($role, ['admin', 'cashier'], true)) {
    settleBillRespond(403, ["status" => "error", "message" => "Only admin or cashier can settle bills"]);
}
$staffId = (int)(settleBillValue($sources, ['staff_id', 'id', 'user_id']) ?? 0);
$authenticatedTenant = trim((string)(settleBillValue($sources, ['tenant_id']) ?? ''));
if ($staffId <= 0 || $authenticatedTenant === '') {
    settleBillRespond(401, ["status" => "error", "message" => "Authenticated staff session is missing billing identity"]);
}
try {
    billingEnsureSchema($conn);
} catch (Throwable $error) {
    error_log("Billing schema check failed: " . $error->getMessage());
    settleBillRespond(500, ["status" => "error", "message" => "Billing database is unavailable"]);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    settleBillRespond(405, ["status" => "error", "message" => "POST is required"]);
}

$data = json_decode(file_get_contents('php://input'), true);
if (!is_array($data)) {
    settleBillRespond(400, ["status" => "error", "message" => "Invalid JSON request"]);
}
$requestedTenant = trim((string)($data['tenant_id'] ?? $authenticatedTenant));
if ($requestedTenant !== $authenticatedTenant) {
    settleBillRespond(403, ["status" => "error", "message" => "Tenant does not match the authenticated staff session"]);
}
$tenantId = $authenticatedTenant;
$idempotencyKey = trim((string)($data['idempotency_key'] ?? ''));
$sessionId = isset($data['session_id']) ? (int)$data['session_id'] : 0;
$orderIds = $data['order_ids'] ?? null;

if (!preg_match('/^[A-Za-z0-9._~-]{16,100}$/', $idempotencyKey)) {
    settleBillRespond(400, ["status" => "error", "message" => "A valid idempotency_key is required"]);
}
$rawPayments = $data['payments'] ?? [[
    'method' => $data['method'] ?? '',
    'amount' => $data['amount'] ?? ''
]];
if (!is_array($rawPayments) || count($rawPayments) < 1 || count($rawPayments) > 20) {
    settleBillRespond(400, ["status" => "error", "message" => "Provide between 1 and 20 payment parts"]);
}
$paymentParts = [];
$submittedCents = 0;
foreach ($rawPayments as $part) {
    if (!is_array($part)) {
        settleBillRespond(400, ["status" => "error", "message" => "Each payment part must include a method and amount"]);
    }
    $partMethod = trim((string)($part['method'] ?? ''));
    $partCents = settleBillCents($part['amount'] ?? '');
    if ($partMethod === '' || strlen($partMethod) > 100 || $partCents === null || $partCents <= 0) {
        settleBillRespond(400, ["status" => "error", "message" => "Each payment part needs a valid method and positive amount with at most two decimals"]);
    }
    $submittedCents += $partCents;
    $paymentParts[] = [
        'method' => $partMethod,
        'cents' => $partCents
    ];
}

if ($sessionId > 0) {
    if ($orderIds !== null) {
        settleBillRespond(400, ["status" => "error", "message" => "Send session_id or order_ids, not both"]);
    }
} else {
    $sessionId = 0;
    if (!is_array($orderIds) || count($orderIds) === 0) {
        settleBillRespond(400, ["status" => "error", "message" => "A session_id or non-empty order_ids array is required"]);
    }
    $orderIds = array_values(array_unique(array_filter(
        array_map('intval', $orderIds),
        function ($id) { return $id > 0; }
    )));
    if (count($orderIds) === 0 || count($orderIds) !== count($data['order_ids'])) {
        settleBillRespond(400, ["status" => "error", "message" => "order_ids must contain valid positive IDs"]);
    }
}

$conn->query("CREATE TABLE IF NOT EXISTS payments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id INT DEFAULT NULL,
    session_id INT DEFAULT NULL,
    tenant_id VARCHAR(100) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    method VARCHAR(100) NOT NULL,
    staff_id BIGINT NOT NULL,
    status ENUM('Completed', 'Failed') NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_payments_idempotency_key (idempotency_key),
    INDEX idx_payments_tenant_created (tenant_id, created_at),
    INDEX idx_payments_session (session_id),
    INDEX idx_payments_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
$conn->query("CREATE TABLE IF NOT EXISTS payment_orders (
    payment_id BIGINT NOT NULL,
    order_id INT NOT NULL,
    PRIMARY KEY (payment_id, order_id),
    INDEX idx_payment_orders_order (order_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
$paymentOrderUnique = $conn->query("SHOW INDEX FROM payment_orders WHERE Key_name = 'uniq_payment_order'");
if ($paymentOrderUnique->num_rows > 0) {
    $conn->query("ALTER TABLE payment_orders DROP INDEX uniq_payment_order");
}
$paymentOrderIndex = $conn->query("SHOW INDEX FROM payment_orders WHERE Key_name = 'idx_payment_orders_order'");
if ($paymentOrderIndex->num_rows === 0) {
    $conn->query("ALTER TABLE payment_orders ADD INDEX idx_payment_orders_order (order_id)");
}

try {
    $conn->begin_transaction();
    $existing = settleBillExistingPayment($conn, $tenantId, $idempotencyKey);
    if ($existing) {
        $conn->commit();
        settleBillRespond(200, settleBillReplayResponse($existing));
    }

    if ($sessionId > 0) {
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
            settleBillRespond(409, ["status" => "error", "message" => "Dining session was not found"]);
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
        $tableLock->close();
        $sessionStmt = $conn->prepare("SELECT id, table_id, table_number, status FROM dining_sessions
            WHERE id = ? AND tenant_id = ? FOR UPDATE");
        $sessionStmt->bind_param("is", $sessionId, $tenantId);
        $sessionStmt->execute();
        $session = $sessionStmt->get_result()->fetch_assoc();
        $sessionStmt->close();
        if (!$session || strtolower((string)$session['status']) === 'settled') {
            $conn->rollback();
            settleBillRespond(409, ["status" => "error", "message" => "Dining session is missing or already settled"]);
        }
        $ordersStmt = $conn->prepare("SELECT id, session_id, status, total_amount FROM orders
            WHERE tenant_id = ? AND session_id = ? AND LOWER(status) <> 'voided'
            ORDER BY id FOR UPDATE");
        $ordersStmt->bind_param("si", $tenantId, $sessionId);
    } else {
        $placeholders = implode(',', array_fill(0, count($orderIds), '?'));
        $types = 's' . str_repeat('i', count($orderIds));
        $ordersStmt = $conn->prepare("SELECT id, status, total_amount FROM orders
            WHERE tenant_id = ? AND id IN ($placeholders) AND LOWER(status) <> 'voided'
            ORDER BY id FOR UPDATE");
        $params = array_merge([$tenantId], $orderIds);
        settleBillBindParams($ordersStmt, $types, $params);
    }
    $ordersStmt->execute();
    $ordersResult = $ordersStmt->get_result();
    $orders = $ordersResult->fetch_all(MYSQLI_ASSOC);
    $ordersStmt->close();

    if (count($orders) === 0 || ($sessionId === 0 && count($orders) !== count($orderIds))) {
        $conn->rollback();
        settleBillRespond(404, ["status" => "error", "message" => "One or more bill orders were not found"]);
    }

    $resolvedOrderIds = [];
    foreach ($orders as $order) {
        if (strtolower((string)$order['status']) === 'settled') {
            $conn->rollback();
            settleBillRespond(409, ["status" => "error", "message" => "An order in this bill is already settled"]);
        }
        $resolvedOrderIds[] = (int)$order['id'];
    }
    $bill = billingCalculateBill($conn, $tenantId, $resolvedOrderIds, null, true);
    $expectedCents = settleBillCents($bill['grand_total']);
    if ($expectedCents === null || $expectedCents <= 0) {
        $conn->rollback();
        settleBillRespond(409, ["status" => "error", "message" => "The stored session bill has no valid item total"]);
    }
    if ($submittedCents !== $expectedCents) {
        $conn->rollback();
        settleBillRespond(409, [
            "status" => "error",
            "message" => "Split payment amounts must exactly equal the current bill total",
            "expected_amount" => number_format($expectedCents / 100, 2, '.', ''),
            "submitted_amount" => number_format($submittedCents / 100, 2, '.', '')
        ]);
    }

    $primaryOrderId = $resolvedOrderIds[0] ?? null;
    $paymentSessionId = $sessionId > 0 ? $sessionId : null;
    $paymentStatus = 'Completed';
    $paymentStmt = $conn->prepare("INSERT INTO payments
        (order_id, session_id, tenant_id, amount, method, staff_id, status, idempotency_key)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    $linkStmt = $conn->prepare("INSERT INTO payment_orders (payment_id, order_id) VALUES (?, ?)");
    $itemLinkStmt = $conn->prepare(
        'INSERT INTO payment_order_items (payment_id, order_item_id) VALUES (?, ?)'
    );
    $recordedPayments = [];
    foreach ($paymentParts as $index => $part) {
        $amount = number_format($part['cents'] / 100, 2, '.', '');
        $method = $part['method'];
        $partKey = $index === 0 ? $idempotencyKey : $idempotencyKey . '.' . $index;
        $paymentStmt->bind_param(
            "iisssiss",
            $primaryOrderId,
            $paymentSessionId,
            $tenantId,
            $amount,
            $method,
            $staffId,
            $paymentStatus,
            $partKey
        );
        $paymentStmt->execute();
        $paymentId = (int)$conn->insert_id;
        foreach ($resolvedOrderIds as $resolvedOrderId) {
            $linkStmt->bind_param("ii", $paymentId, $resolvedOrderId);
            $linkStmt->execute();
        }
        if ($index === 0) {
            foreach ($bill['items'] as $billItem) {
                $billItemId = (int)$billItem['id'];
                $itemLinkStmt->bind_param('ii', $paymentId, $billItemId);
                $itemLinkStmt->execute();
            }
        }
        $recordedPayments[] = [
            'payment_id' => $paymentId,
            'amount' => $amount,
            'method' => $method,
            'payment_status' => $paymentStatus,
        ];
    }
    $paymentStmt->close();
    $linkStmt->close();
    $itemLinkStmt->close();

    $remainingForOrders = $conn->prepare(
        "SELECT COUNT(*) AS remaining_count
         FROM order_items oi
         LEFT JOIN payment_order_items poi ON poi.order_item_id = oi.id
         WHERE oi.order_id = ? AND poi.order_item_id IS NULL
           AND LOWER(oi.status) NOT IN ('cancelled', 'canceled')"
    );
    $settleOrder = $conn->prepare(
        "UPDATE orders SET status = 'Settled'
         WHERE id = ? AND tenant_id = ? AND LOWER(status) NOT IN ('settled', 'voided')"
    );
    foreach ($resolvedOrderIds as $resolvedOrderId) {
        $remainingForOrders->bind_param('i', $resolvedOrderId);
        $remainingForOrders->execute();
        $remainingCount = (int)$remainingForOrders->get_result()
            ->fetch_assoc()['remaining_count'];
        if ($remainingCount === 0) {
            $settleOrder->bind_param('is', $resolvedOrderId, $tenantId);
            $settleOrder->execute();
        }
    }
    $remainingForOrders->close();
    $settleOrder->close();

    if ($sessionId > 0) {
        $remainingSession = $conn->prepare(
            "SELECT COUNT(*) AS remaining_count
             FROM orders o
             INNER JOIN order_items oi ON oi.order_id = o.id
             LEFT JOIN payment_order_items poi ON poi.order_item_id = oi.id
             WHERE o.tenant_id = ? AND o.session_id = ?
               AND LOWER(o.status) <> 'voided'
               AND poi.order_item_id IS NULL
               AND LOWER(oi.status) NOT IN ('cancelled', 'canceled')"
        );
        $remainingSession->bind_param('si', $tenantId, $sessionId);
        $remainingSession->execute();
        $sessionRemainingCount = (int)$remainingSession->get_result()
            ->fetch_assoc()['remaining_count'];
        $remainingSession->close();

        if ($sessionRemainingCount === 0) {
            $updateOrders = $conn->prepare(
                "UPDATE orders SET status = 'Settled'
                 WHERE tenant_id = ? AND session_id = ?
                   AND LOWER(status) NOT IN ('settled', 'voided')"
            );
            $updateOrders->bind_param('si', $tenantId, $sessionId);
            $updateOrders->execute();
            $updateOrders->close();
            $nextSessionStatus = 'Settled';
            $nextTableStatus = 'Available';
        } else {
            $nextSessionStatus = 'Open';
            $nextTableStatus = 'Dining';
        }

        $updateSession = $conn->prepare(
            'UPDATE dining_sessions SET status = ?, last_modified = CURRENT_TIMESTAMP
             WHERE id = ? AND tenant_id = ?'
        );
        $updateSession->bind_param('sis', $nextSessionStatus, $sessionId, $tenantId);
        $updateSession->execute();
        if ($updateSession->affected_rows !== 1) {
            throw new RuntimeException('Could not update the dining session state');
        }
        $updateSession->close();

        $tableId = (int)($session['table_id'] ?? 0);
        if ($tableId > 0) {
            $updateTable = $conn->prepare(
                'UPDATE restaurant_tables SET status = ? WHERE id = ? AND tenant_id = ?'
            );
            $updateTable->bind_param('sis', $nextTableStatus, $tableId, $tenantId);
        } else {
            $tableNumber = (int)$session['table_number'];
            $updateTable = $conn->prepare(
                'UPDATE restaurant_tables SET status = ? WHERE table_number = ? AND tenant_id = ?'
            );
            $updateTable->bind_param('sis', $nextTableStatus, $tableNumber, $tenantId);
        }
        $updateTable->execute();
        $updateTable->close();
    }

    $conn->commit();
    settleBillRespond(200, [
        "status" => "success",
        "message" => "Bill settled successfully",
        "payment_id" => $recordedPayments[0]['payment_id'],
        "amount" => number_format($submittedCents / 100, 2, '.', ''),
        "method" => count($paymentParts) === 1 ? $paymentParts[0]['method'] : null,
        "payment_status" => $paymentStatus,
        "order_id" => $primaryOrderId,
        "session_id" => $paymentSessionId,
        "payments" => $recordedPayments,
        "idempotent_replay" => false
    ]);
} catch (BillingConfigurationException $error) {
    try { $conn->rollback(); } catch (Throwable $rollbackError) {}
    settleBillRespond(409, ['status' => 'error', 'message' => $error->getMessage()]);
} catch (Throwable $error) {
    try { $conn->rollback(); } catch (Throwable $ignored) {}
    if ((int)$error->getCode() === 1062) {
        $existing = settleBillExistingPayment($conn, $tenantId, $idempotencyKey);
        if ($existing) {
            settleBillRespond(200, settleBillReplayResponse($existing));
        }
    }
    error_log("Bill settlement failed: " . $error->getMessage());
    settleBillRespond(500, ["status" => "error", "message" => "Bill settlement failed; verify status before retrying"]);
}
?>
