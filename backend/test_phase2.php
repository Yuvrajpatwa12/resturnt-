<?php
header('Content-Type: application/json; charset=UTF-8');

function phase2AddResult(&$results, $name, $status, $message) {
    $results[] = [
        'test' => $name,
        'status' => $status,
        'message' => $message
    ];
}

function phase2HttpRequest($url, $method = 'GET', $payload = null, $cookie = '') {
    if (!function_exists('curl_init')) {
        return ['available' => false, 'error' => 'PHP cURL extension is unavailable'];
    }
    $curl = curl_init($url);
    if ($curl === false) {
        return ['available' => false, 'error' => 'Could not initialize cURL'];
    }
    $headers = ['Accept: application/json'];
    if ($payload !== null) {
        $headers[] = 'Content-Type: application/json';
    }
    if ($cookie !== '') {
        $headers[] = 'Cookie: ' . $cookie;
    }
    curl_setopt_array($curl, [
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_POSTFIELDS => $payload === null ? null : json_encode($payload),
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT => 15,
        CURLOPT_FOLLOWLOCATION => false
    ]);
    $body = curl_exec($curl);
    $error = curl_error($curl);
    $httpCode = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
    curl_close($curl);
    if ($body === false) {
        return ['available' => false, 'error' => $error ?: 'HTTP request failed'];
    }
    return [
        'available' => true,
        'http_code' => $httpCode,
        'body' => $body,
        'json' => json_decode($body, true)
    ];
}

function phase2EndpointUrl($file) {
    $https = !empty($_SERVER['HTTPS']) && strtolower((string)$_SERVER['HTTPS']) !== 'off';
    $scheme = $https ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'startupsgo.tech';
    $directory = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '/saas_api/test_phase2.php')), '/');
    return $scheme . '://' . $host . $directory . '/' . $file;
}

function phase2TableExists($conn, $tableName) {
    $stmt = $conn->prepare(
        'SELECT COUNT(*) AS table_count FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?'
    );
    $stmt->bind_param('s', $tableName);
    $stmt->execute();
    $exists = (int)$stmt->get_result()->fetch_assoc()['table_count'] > 0;
    $stmt->close();
    return $exists;
}

function phase2ReadSessionStatus($conn, $sessionId, $tenantId) {
    $stmt = $conn->prepare('SELECT status FROM dining_sessions WHERE id = ? AND tenant_id = ? LIMIT 1');
    $stmt->bind_param('is', $sessionId, $tenantId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ? (string)$row['status'] : null;
}

function phase2DeleteOrderLinks($conn, $orderIds) {
    if (!$orderIds) return;
    $stmt = $conn->prepare('DELETE FROM payment_orders WHERE order_id = ?');
    foreach ($orderIds as $orderId) {
        $id = (int)$orderId;
        $stmt->bind_param('i', $id);
        $stmt->execute();
    }
    $stmt->close();
}

function phase2Cleanup($conn, &$fixture) {
    if (!($conn instanceof mysqli) || empty($fixture)) return true;
    try {
        $tenantId = (string)($fixture['tenant_id'] ?? '');
        $sessionId = (int)($fixture['session_id'] ?? 0);
        $tableId = (int)($fixture['table_id'] ?? 0);
        $orderIds = $fixture['order_ids'] ?? [];

        if ($tenantId !== '' && $sessionId > 0) {
            $orderLookup = $conn->prepare('SELECT id FROM orders WHERE tenant_id = ? AND session_id = ?');
            $orderLookup->bind_param('si', $tenantId, $sessionId);
            $orderLookup->execute();
            $orderRows = $orderLookup->get_result();
            while ($row = $orderRows->fetch_assoc()) {
                $orderIds[] = (int)$row['id'];
            }
            $orderLookup->close();
            $orderIds = array_values(array_unique(array_map('intval', $orderIds)));
            $fixture['order_ids'] = $orderIds;
        }

        if ($tenantId !== '' && $sessionId > 0 && phase2TableExists($conn, 'notifications')) {
            $notificationIds = [];
            foreach ($orderIds as $orderId) {
                $expectedTitle = 'New Order #' . (int)$orderId;
                $notice = $conn->prepare(
                    'SELECT id FROM notifications WHERE tenant_id = ? AND title = ?'
                );
                $notice->bind_param('ss', $tenantId, $expectedTitle);
                $notice->execute();
                $noticeRows = $notice->get_result();
                while ($row = $noticeRows->fetch_assoc()) {
                    $notificationIds[] = (int)$row['id'];
                }
                $notice->close();
            }
            $notificationIds = array_values(array_unique($notificationIds));

            if ($notificationIds && phase2TableExists($conn, 'notification_email_queue')) {
                $queueDelete = $conn->prepare('DELETE FROM notification_email_queue WHERE notification_id = ?');
                foreach ($notificationIds as $notificationId) {
                    $queueDelete->bind_param('i', $notificationId);
                    $queueDelete->execute();
                }
                $queueDelete->close();
            }
            if ($notificationIds) {
                $noticeDelete = $conn->prepare('DELETE FROM notifications WHERE id = ?');
                foreach ($notificationIds as $notificationId) {
                    $noticeDelete->bind_param('i', $notificationId);
                    $noticeDelete->execute();
                }
                $noticeDelete->close();
            }
        }

        if ($sessionId > 0 && phase2TableExists($conn, 'payments')) {
            $paymentIds = [];
            $paymentLookup = $conn->prepare('SELECT id FROM payments WHERE session_id = ? AND tenant_id = ?');
            $paymentLookup->bind_param('is', $sessionId, $tenantId);
            $paymentLookup->execute();
            $paymentRows = $paymentLookup->get_result();
            while ($row = $paymentRows->fetch_assoc()) {
                $paymentIds[] = (int)$row['id'];
            }
            $paymentLookup->close();
            if ($paymentIds && phase2TableExists($conn, 'payment_order_items')) {
                $paymentItemDelete = $conn->prepare(
                    'DELETE FROM payment_order_items WHERE payment_id = ?'
                );
                foreach ($paymentIds as $paymentId) {
                    $paymentItemDelete->bind_param('i', $paymentId);
                    $paymentItemDelete->execute();
                }
                $paymentItemDelete->close();
            }
            if ($paymentIds && phase2TableExists($conn, 'payment_orders')) {
                $paymentOrderDelete = $conn->prepare('DELETE FROM payment_orders WHERE payment_id = ?');
                foreach ($paymentIds as $paymentId) {
                    $paymentOrderDelete->bind_param('i', $paymentId);
                    $paymentOrderDelete->execute();
                }
                $paymentOrderDelete->close();
            }
            $paymentDelete = $conn->prepare('DELETE FROM payments WHERE session_id = ? AND tenant_id = ?');
            $paymentDelete->bind_param('is', $sessionId, $tenantId);
            $paymentDelete->execute();
            $paymentDelete->close();
        }

        if ($orderIds && phase2TableExists($conn, 'payment_orders')) {
            phase2DeleteOrderLinks($conn, $orderIds);
        }
        if ($sessionId > 0) {
            if (phase2TableExists($conn, 'payment_order_items')) {
                $paymentItemDelete = $conn->prepare(
                    'DELETE poi FROM payment_order_items poi
                     INNER JOIN order_items oi ON oi.id = poi.order_item_id
                     INNER JOIN orders o ON o.id = oi.order_id
                     WHERE o.tenant_id = ? AND o.session_id = ?'
                );
                $paymentItemDelete->bind_param('si', $tenantId, $sessionId);
                $paymentItemDelete->execute();
                $paymentItemDelete->close();
            }
            $itemDelete = $conn->prepare(
                'DELETE oi FROM order_items oi
                 INNER JOIN orders o ON o.id = oi.order_id
                 WHERE o.tenant_id = ? AND o.session_id = ?'
            );
            $itemDelete->bind_param('si', $tenantId, $sessionId);
            $itemDelete->execute();
            $itemDelete->close();
            $orderDelete = $conn->prepare('DELETE FROM orders WHERE tenant_id = ? AND session_id = ?');
            $orderDelete->bind_param('si', $tenantId, $sessionId);
            $orderDelete->execute();
            $orderDelete->close();
            $sessionDelete = $conn->prepare('DELETE FROM dining_sessions WHERE id = ? AND tenant_id = ?');
            $sessionDelete->bind_param('is', $sessionId, $tenantId);
            $sessionDelete->execute();
            $sessionDelete->close();
        }
        if ($tableId > 0) {
            $tableDelete = $conn->prepare('DELETE FROM restaurant_tables WHERE id = ? AND tenant_id = ?');
            $tableDelete->bind_param('is', $tableId, $tenantId);
            $tableDelete->execute();
            $tableDelete->close();
        }
        return true;
    } catch (Throwable $error) {
        error_log('Phase 2 verifier cleanup failed: ' . $error->getMessage());
        return false;
    }
}

$results = [];
$fixture = [];
$conn = null;
$phase2ResponseSent = false;
ini_set('display_errors', '0');
error_reporting(E_ALL);
register_shutdown_function(function () use (&$conn, &$fixture, &$phase2ResponseSent) {
    phase2Cleanup($conn, $fixture);
    if ($phase2ResponseSent) return;
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
        error_log('Phase 2 verifier stopped unexpectedly: ' . $error['message']);
        if (!headers_sent()) {
            http_response_code(500);
            header('Content-Type: application/json; charset=UTF-8');
        }
        echo json_encode([
            'access_url' => phase2EndpointUrl('test_phase2.php'),
            'status' => 'FAIL',
            'message' => 'The verifier stopped because of a server-side PHP error. Check the Hostinger PHP error log.'
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        $phase2ResponseSent = true;
    }
});

try {
    require_once __DIR__ . '/db_config.php';
    require_once __DIR__ . '/staff_auth.php';
    require_once __DIR__ . '/billing_common.php';
    if (!isset($conn) || !($conn instanceof mysqli) || $conn->connect_error) {
        throw new RuntimeException('Could not connect to the configured MySQL database.');
    }
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }

    $staff = isset($_SESSION['staff']) && is_array($_SESSION['staff']) ? $_SESSION['staff'] : [];
    $role = strtolower(trim((string)($staff['role'] ?? '')));
    $tenantId = trim((string)($staff['tenant_id'] ?? ''));
    $staffId = (int)($staff['id'] ?? 0);
    $cookie = (string)($_SERVER['HTTP_COOKIE'] ?? '');
    $baseUrl = phase2EndpointUrl('');
    $baseUrl = rtrim($baseUrl, '/');

    $getBillSource = is_file(__DIR__ . '/get_session_bill.php')
        ? preg_replace('/\s+/', ' ', (string)file_get_contents(__DIR__ . '/get_session_bill.php'))
        : '';
    $combinedSource = strpos($getBillSource, 'billingCalculateBill') !== false &&
        strpos($getBillSource, 'session_id = ?') !== false;
    phase2AddResult(
        $results,
        'Combined KOT batches use one session bill source',
        $combinedSource ? 'PASS' : 'FAIL',
        $combinedSource
            ? 'get_session_bill.php loads orders by dining session and calculates their combined line items through the shared server-side bill calculator (source check).'
            : 'Could not confirm session-wide order lookup and shared server-side bill calculation.'
    );

    $authHelperLoaded = function_exists('requireAuth');
    phase2AddResult(
        $results,
        'Staff authentication helper is loaded',
        $authHelperLoaded ? 'PASS' : 'FAIL',
        $authHelperLoaded ? 'The verifier loaded requireAuth().' : 'Deploy staff_auth.php beside the billing endpoints.'
    );

    $reopenSource = is_file(__DIR__ . '/reopen_session.php')
        ? preg_replace('/\s+/', ' ', (string)file_get_contents(__DIR__ . '/reopen_session.php'))
        : '';
    $adminAllowList = strpos($reopenSource, "requireAuth(\$conn, ['admin', 'super_admin'])") !== false;
    phase2AddResult(
        $results,
        'Reopen endpoint allows only Admin and Super Admin',
        $adminAllowList ? 'PASS' : 'FAIL',
        $adminAllowList
            ? 'reopen_session.php calls requireAuth() with exactly admin and super_admin (source check).'
            : 'Could not verify the required admin-only requireAuth() allow-list.'
    );

    if (session_status() === PHP_SESSION_ACTIVE) {
        session_write_close();
    }
    $anonymousReopen = phase2HttpRequest(
        $baseUrl . '/reopen_session.php',
        'POST',
        ['session_id' => 1]
    );
    $anonymousDenied = $anonymousReopen['available'] &&
        in_array($anonymousReopen['http_code'], [401, 403], true);
    phase2AddResult(
        $results,
        'Reopen rejects unauthenticated requests',
        !$anonymousReopen['available'] ? 'SKIP' : ($anonymousDenied ? 'PASS' : 'FAIL'),
        !$anonymousReopen['available']
            ? 'Could not make the anonymous endpoint request: ' . $anonymousReopen['error']
            : ($anonymousDenied
                ? 'A request without a session cookie was rejected with HTTP ' . $anonymousReopen['http_code'] . '.'
                : 'Expected HTTP 401 or 403, received HTTP ' . $anonymousReopen['http_code'] . '.')
    );

    $waiterDenied = $adminAllowList && !in_array('waiter', ['admin', 'super_admin'], true);
    $waiterMessage = $waiterDenied
        ? 'The source allow-list excludes waiter. '
        : 'Could not verify that waiter is excluded from the allow-list. ';
    if ($role === 'waiter' && $cookie !== '') {
        $waiterResponse = phase2HttpRequest(
            $baseUrl . '/reopen_session.php',
            'POST',
            ['session_id' => 1],
            $cookie
        );
        $waiterDenied = $waiterDenied && $waiterResponse['available'] &&
            in_array($waiterResponse['http_code'], [401, 403], true);
        $waiterMessage .= $waiterResponse['available']
            ? 'The live waiter session received HTTP ' . $waiterResponse['http_code'] . '.'
            : 'Live waiter request unavailable: ' . $waiterResponse['error'];
    } else {
        $waiterMessage .= 'No live waiter cookie was available, so this is a source/logic check only.';
    }
    phase2AddResult(
        $results,
        'Waiter cannot reopen a session',
        $waiterDenied ? 'PASS' : 'FAIL',
        $waiterMessage
    );

    $authorizedRole = in_array($role, ['admin', 'cashier', 'waiter'], true) &&
        $staffId > 0 && $tenantId !== '' && $cookie !== '';
    if (!$authorizedRole || !function_exists('curl_init')) {
        $reason = !$authorizedRole
            ? 'Open this verifier in a logged-in admin, cashier, or waiter browser session to run disposable session tests.'
            : 'PHP cURL is unavailable; live endpoint tests were skipped.';
        foreach ([
            'Server bill combines multiple KOT batches and uses tenant rates',
            'Session transitions Open to ReadyForBilling',
            'place_order rejects additions while ReadyForBilling with HTTP 409',
            'Settlement transitions the session to Settled',
            'place_order rejects additions while Settled with HTTP 409',
            'Admin reopens the session to Open',
            'Adding an item succeeds after admin reopening'
        ] as $testName) {
            phase2AddResult($results, $testName, 'SKIP', $reason);
        }
    } else {
        billingEnsureSchema($conn);
        $fixture['tenant_id'] = $tenantId;
        $fixture['created_at'] = date('Y-m-d H:i:s');
        $tableInsert = $conn->prepare(
            "INSERT INTO restaurant_tables (tenant_id, table_number, status) VALUES (?, ?, 'Dining')"
        );
        $testTableNumber = 0;
        $tableExists = $conn->prepare('SELECT id FROM restaurant_tables WHERE tenant_id = ? AND table_number = ? LIMIT 1');
        for ($attempt = 0; $attempt < 5; $attempt++) {
            $candidateTableNumber = random_int(1000000000, 1999999999);
            $tableExists->bind_param('si', $tenantId, $candidateTableNumber);
            $tableExists->execute();
            if ($tableExists->get_result()->num_rows === 0) {
                $testTableNumber = $candidateTableNumber;
                break;
            }
        }
        $tableExists->close();
        if ($testTableNumber <= 0) {
            throw new RuntimeException('Could not reserve a unique test table number.');
        }
        $tableInsert->bind_param('si', $tenantId, $testTableNumber);
        $tableInsert->execute();
        $fixture['table_id'] = (int)$conn->insert_id;
        $tableInsert->close();

        $sessionInsert = $conn->prepare(
            "INSERT INTO dining_sessions (tenant_id, table_id, table_number, status)
             VALUES (?, ?, ?, 'Open')"
        );
        $sessionInsert->bind_param('sii', $tenantId, $fixture['table_id'], $testTableNumber);
        $sessionInsert->execute();
        $fixture['session_id'] = (int)$conn->insert_id;
        $sessionInsert->close();

        $orderInsert = $conn->prepare(
            "INSERT INTO orders (tenant_id, table_id, user_id, customer_email, total_amount, status, session_id, created_at)
             VALUES (?, ?, 'phase2_test', '', ?, 'Pending', ?, NOW())"
        );
        $itemInsert = $conn->prepare(
            "INSERT INTO order_items
             (order_id, product_id, product_name, quantity, price_at_order, status)
             VALUES (?, 0, ?, ?, ?, ?)"
        );
        $fixtureOrderTotals = ['20.00', '5.00', '400.00'];
        $fixtureItems = [
            ['Phase 2 test item A', 2, '10.00', 'Completed'],
            ['Phase 2 test item B', 1, '5.00', 'Served'],
            ['Phase 2 pending item', 4, '100.00', 'Pending']
        ];
        foreach ($fixtureOrderTotals as $index => $orderTotal) {
            $tableIdForOrder = (int)$fixture['table_id'];
            $sessionIdForOrder = (int)$fixture['session_id'];
            $orderTotalAmount = (float)$orderTotal;
            $orderInsert->bind_param('sidi', $tenantId, $tableIdForOrder, $orderTotalAmount, $sessionIdForOrder);
            $orderInsert->execute();
            $orderId = (int)$conn->insert_id;
            $fixture['order_ids'][] = $orderId;
            $item = $fixtureItems[$index];
            $itemName = $item[0];
            $itemQuantity = $item[1];
            $itemPrice = (float)$item[2];
            $itemStatus = $item[3];
            $itemInsert->bind_param(
                'isids',
                $orderId,
                $itemName,
                $itemQuantity,
                $itemPrice,
                $itemStatus
            );
            $itemInsert->execute();
        }
        $orderInsert->close();
        $itemInsert->close();

        $rates = billingGetRates($conn, $tenantId);
        $subtotalCents = 2500;
        $serviceCents = billingRateCents($subtotalCents, $rates['service_charge']);
        $taxCents = billingRateCents($subtotalCents + $serviceCents, $rates['vat_percentage']);
        $expectedBill = [
            'subtotal' => '25.00',
            'service_charge' => number_format($serviceCents / 100, 2, '.', ''),
            'tax' => number_format($taxCents / 100, 2, '.', ''),
            'grand_total' => number_format(($subtotalCents + $serviceCents + $taxCents) / 100, 2, '.', '')
        ];
        $billResponse = phase2HttpRequest(
            $baseUrl . '/get_session_bill.php?session_id=' . (int)$fixture['session_id'],
            'GET',
            null,
            $cookie
        );
        $billJson = isset($billResponse['json']) && is_array($billResponse['json'])
            ? $billResponse['json']
            : [];
        $billPassed = $billResponse['available'] &&
            $billResponse['http_code'] === 200 &&
            ($billJson['status'] ?? '') === 'success' &&
            count($billJson['order_ids'] ?? []) === 3 &&
            count($billJson['items'] ?? []) === 2 &&
            count($billJson['unbilled_items'] ?? []) === 1 &&
            (string)($billJson['unbilled_items'][0]['status'] ?? '') === 'Pending' &&
            (string)($billJson['unbilled_items'][0]['line_total'] ?? '') === '0.00' &&
            (string)($billJson['unbilled_items'][0]['financial_contribution'] ?? '') === '0.00';
        foreach ($expectedBill as $key => $value) {
            $billPassed = $billPassed && (string)($billJson[$key] ?? '') === $value;
        }
        $ratesMatch = (float)($billJson['rates']['vat_percentage'] ?? -1) === (float)$rates['vat_percentage'] &&
            (float)($billJson['rates']['service_charge'] ?? -1) === (float)$rates['service_charge'];
        $billPassed = $billPassed && $ratesMatch;
        phase2AddResult(
            $results,
            'Server bill combines multiple KOT batches and uses tenant rates',
            $billPassed ? 'PASS' : 'FAIL',
            $billPassed
                ? 'The endpoint returned both fixture batches and matched configured rates. Subtotal ' .
                    $expectedBill['subtotal'] . ', service ' . $expectedBill['service_charge'] .
                    ', VAT ' . $expectedBill['tax'] . ', total ' . $expectedBill['grand_total'] .
                    '; the pending item contributed exactly 0.00.'
                : 'The session bill did not match served items, zero-value pending items, and tenant-configured VAT/service rates.'
        );

        $pendingOrderId = (int)$fixture['order_ids'][2];
        $servePendingItem = $conn->prepare(
            "UPDATE order_items SET status = 'Completed' WHERE order_id = ?"
        );
        $servePendingItem->bind_param('i', $pendingOrderId);
        $servePendingItem->execute();
        $servePendingItem->close();
        $subtotalCents = 42500;
        $serviceCents = billingRateCents($subtotalCents, $rates['service_charge']);
        $taxCents = billingRateCents($subtotalCents + $serviceCents, $rates['vat_percentage']);
        $expectedBill = [
            'subtotal' => '425.00',
            'service_charge' => number_format($serviceCents / 100, 2, '.', ''),
            'tax' => number_format($taxCents / 100, 2, '.', ''),
            'grand_total' => number_format(($subtotalCents + $serviceCents + $taxCents) / 100, 2, '.', '')
        ];

        $statusResponse = phase2HttpRequest(
            $baseUrl . '/update_session_status.php',
            'POST',
            ['session_id' => (int)$fixture['session_id'], 'status' => 'ReadyForBilling'],
            $cookie
        );
        $statusIsReady = $statusResponse['available'] &&
            $statusResponse['http_code'] === 200 &&
            phase2ReadSessionStatus($conn, (int)$fixture['session_id'], $tenantId) === 'ReadyForBilling';
        phase2AddResult(
            $results,
            'Session transitions Open to ReadyForBilling',
            $statusIsReady ? 'PASS' : 'FAIL',
            $statusIsReady
                ? 'The authenticated status endpoint moved the disposable session from Open to ReadyForBilling.'
                : 'Could not move the disposable session to ReadyForBilling. HTTP ' .
                    (string)($statusResponse['http_code'] ?? 'unavailable') .
                    (isset($statusResponse['json']['message'])
                        ? ': ' . $statusResponse['json']['message']
                        : (isset($statusResponse['error']) ? ': ' . $statusResponse['error'] : ''))
        );

        $activeProductId = 0;
        $productColumns = $conn->query("SHOW COLUMNS FROM products");
        $productColumnNames = [];
        while ($productColumn = $productColumns->fetch_assoc()) {
            $productColumnNames[strtolower($productColumn['Field'])] = $productColumn['Field'];
        }
        $activeProductColumn = $productColumnNames['is_available'] ??
            $productColumnNames['is_active'] ??
            $productColumnNames['status'] ??
            null;
        if ($activeProductColumn && isset($productColumnNames['tenant_id'])) {
            $activeCondition = strtolower($activeProductColumn) === 'status'
                ? "LOWER(`$activeProductColumn`) IN ('active', 'available', '1')"
                : "`$activeProductColumn` = 1";
            $productLookup = $conn->prepare(
                "SELECT id FROM products WHERE tenant_id = ? AND $activeCondition LIMIT 1"
            );
            $productLookup->bind_param("s", $tenantId);
            $productLookup->execute();
            $activeProduct = $productLookup->get_result()->fetch_assoc();
            $productLookup->close();
            $activeProductId = (int)($activeProduct['id'] ?? 0);
        }
        $placePayload = [
            'tenant_id' => $tenantId,
            'table_number' => $testTableNumber,
            'idempotency_key' => bin2hex(random_bytes(16)),
            'user_id' => 'guest',
            'customer_email' => '',
            'total_amount' => 1,
            'items' => [[
                'product_id' => $activeProductId,
                'name' => 'Disposable rejected item',
                'quantity' => 1,
                'price' => 1
            ]]
        ];
        $readyReject = phase2HttpRequest($baseUrl . '/place_order.php', 'POST', $placePayload);
        $readyRejected = $readyReject['available'] && $readyReject['http_code'] === 409 &&
            phase2ReadSessionStatus($conn, (int)$fixture['session_id'], $tenantId) === 'ReadyForBilling';
        phase2AddResult(
            $results,
            'place_order rejects additions while ReadyForBilling with HTTP 409',
            $readyRejected ? 'PASS' : 'FAIL',
            $readyRejected
                ? 'place_order.php rejected the attempted item with HTTP 409 and left the session unchanged.'
                : 'Expected HTTP 409, received HTTP ' .
                    (string)($readyReject['http_code'] ?? 'unavailable') .
                    '; session status is ' .
                    (string)(phase2ReadSessionStatus($conn, (int)$fixture['session_id'], $tenantId) ?? 'missing') .
                    (isset($readyReject['json']['message']) ? ': ' . $readyReject['json']['message'] : '')
        );

        $settlementStatus = 'SKIP';
        $settlementMessage = 'A live admin/cashier session and cURL are required to settle the disposable fixture.';
        $reopenStatus = 'SKIP';
        $reopenMessage = 'A live admin/super_admin session is required to exercise reopen_session.php.';
        $addAfterReopenStatus = 'SKIP';
        $addAfterReopenMessage = 'Skipped because an authorized Admin reopen could not be attempted.';
        if (in_array($role, ['admin', 'cashier'], true)) {
            $key = 'phase2_test_' . bin2hex(random_bytes(16));
            $settleResponse = phase2HttpRequest(
                $baseUrl . '/settle_bill.php',
                'POST',
                [
                    'tenant_id' => $tenantId,
                    'session_id' => (int)$fixture['session_id'],
                    'amount' => $expectedBill['grand_total'],
                    'method' => 'Phase 2 disposable test',
                    'idempotency_key' => $key
                ],
                $cookie
            );
            $settlementPassed = $settleResponse['available'] &&
                $settleResponse['http_code'] === 200 &&
                phase2ReadSessionStatus($conn, (int)$fixture['session_id'], $tenantId) === 'Settled';
            $settlementStatus = $settlementPassed ? 'PASS' : 'FAIL';
            $settlementMessage = $settlementPassed
                ? 'The existing settlement endpoint completed the disposable session and moved its status to Settled.'
                : 'Settlement did not move the disposable session to Settled. HTTP ' .
                    (string)($settleResponse['http_code'] ?? 'unavailable') .
                    (isset($settleResponse['json']['message'])
                        ? ': ' . $settleResponse['json']['message']
                        : (isset($settleResponse['error']) ? ': ' . $settleResponse['error'] : ''));
            phase2AddResult($results, 'Settlement transitions the session to Settled', $settlementStatus, $settlementMessage);

            $settledReject = phase2HttpRequest($baseUrl . '/place_order.php', 'POST', $placePayload);
            $settledRejected = $settledReject['available'] && $settledReject['http_code'] === 409 &&
                phase2ReadSessionStatus($conn, (int)$fixture['session_id'], $tenantId) === 'Settled';
            phase2AddResult(
                $results,
                'place_order rejects additions while Settled with HTTP 409',
                $settledRejected ? 'PASS' : 'FAIL',
                $settledRejected
                    ? 'place_order.php rejected the attempted item with HTTP 409 and left the session Settled.'
                    : 'Expected HTTP 409, received HTTP ' .
                        (string)($settledReject['http_code'] ?? 'unavailable') .
                        '; session status is ' .
                        (string)(phase2ReadSessionStatus($conn, (int)$fixture['session_id'], $tenantId) ?? 'missing') .
                        (isset($settledReject['json']['message']) ? ': ' . $settledReject['json']['message'] : '')
            );

            if ($role === 'admin') {
                $reopenResponse = phase2HttpRequest(
                    $baseUrl . '/reopen_session.php',
                    'POST',
                    ['session_id' => (int)$fixture['session_id']],
                    $cookie
                );
                $reopened = $reopenResponse['available'] &&
                    $reopenResponse['http_code'] === 200 &&
                    phase2ReadSessionStatus($conn, (int)$fixture['session_id'], $tenantId) === 'Open';
                $reopenStatus = $reopened ? 'PASS' : 'FAIL';
                $reopenMessage = $reopened
                    ? 'The authenticated Admin reopened the disposable session; its status is Open.'
                    : 'The Admin reopen request did not reset the disposable session to Open.';
                phase2AddResult($results, 'Admin reopens the session to Open', $reopenStatus, $reopenMessage);

                if ($reopened) {
                    $addResponse = phase2HttpRequest($baseUrl . '/place_order.php', 'POST', $placePayload);
                    $added = $addResponse['available'] &&
                        $addResponse['http_code'] === 200 &&
                        ($addResponse['json']['status'] ?? '') === 'success';
                    $addAfterReopenStatus = $added ? 'PASS' : 'FAIL';
                    $addAfterReopenMessage = $added
                        ? 'A disposable item was accepted after reopening. Its order and related notifications are removed during cleanup.'
                        : 'The item-add request did not succeed after reopening: HTTP ' .
                            (string)($addResponse['http_code'] ?? 'unavailable') . '.';
                }
                phase2AddResult(
                    $results,
                    'Adding an item succeeds after admin reopening',
                    $addAfterReopenStatus,
                    $addAfterReopenMessage
                );
            } else {
                phase2AddResult($results, 'Admin reopens the session to Open', 'SKIP', $reopenMessage);
                phase2AddResult($results, 'Adding an item succeeds after admin reopening', 'SKIP', $addAfterReopenMessage);
            }
        } else {
            phase2AddResult($results, 'Settlement transitions the session to Settled', 'SKIP', $settlementMessage);
            phase2AddResult(
                $results,
                'place_order rejects additions while Settled with HTTP 409',
                'SKIP',
                'Run this test while logged in as an Admin or Cashier to settle the disposable fixture first.'
            );
            phase2AddResult($results, 'Admin reopens the session to Open', 'SKIP', $reopenMessage);
            phase2AddResult($results, 'Adding an item succeeds after admin reopening', 'SKIP', $addAfterReopenMessage);
        }
    }

    $cleanupPassed = phase2Cleanup($conn, $fixture);
    if ($cleanupPassed) {
        $fixture = [];
    }
    phase2AddResult(
        $results,
        'Disposable test data cleanup',
        $cleanupPassed ? 'PASS' : 'FAIL',
        $cleanupPassed
            ? 'The temporary session, orders, items, payment, and related notifications were removed.'
            : 'Cleanup failed; inspect the PHP error log and remove only the Phase 2 test fixture for this verifier run.'
    );

    $hasFailures = false;
    $hasSkips = false;
    foreach ($results as $result) {
        if ($result['status'] === 'FAIL') {
            $hasFailures = true;
        } elseif ($result['status'] === 'SKIP') {
            $hasSkips = true;
        }
    }
    echo json_encode([
        'access_url' => phase2EndpointUrl('test_phase2.php'),
        'status' => $hasFailures ? 'FAIL' : ($hasSkips ? 'PARTIAL' : 'PASS'),
        'message' => 'Live session tests use disposable test rows and attempt cleanup before the report is returned.',
        'results' => $results
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    $phase2ResponseSent = true;
} catch (Throwable $error) {
    error_log('Phase 2 verification failed: ' . $error->getMessage());
    $cleanupPassed = phase2Cleanup($conn, $fixture);
    if ($cleanupPassed) {
        $fixture = [];
    }
    phase2AddResult(
        $results,
        'Disposable test data cleanup',
        $cleanupPassed ? 'PASS' : 'FAIL',
        $cleanupPassed
            ? 'The temporary session and related test data were removed.'
            : 'Cleanup failed; inspect the PHP error log and remove only this verifier run’s fixture.'
    );
    phase2AddResult($results, 'Verifier execution', 'FAIL', 'A verifier error occurred; check the PHP error log.');
    echo json_encode([
        'access_url' => phase2EndpointUrl('test_phase2.php'),
        'status' => 'FAIL',
        'message' => 'The verifier could not complete.',
        'results' => $results
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    $phase2ResponseSent = true;
} finally {
    phase2Cleanup($conn, $fixture);
}
?>
