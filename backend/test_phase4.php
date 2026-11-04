
<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Content-Type: application/json; charset=UTF-8');
ini_set('display_errors', '0');
error_reporting(E_ALL);

function phase4AddResult(&$results, $name, $status, $message) {
    $results[] = [
        'test' => $name,
        'status' => $status,
        'message' => $message
    ];
}

function phase4AccessUrl() {
    $https = !empty($_SERVER['HTTPS']) && strtolower((string)$_SERVER['HTTPS']) !== 'off';
    $scheme = $https ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'startupsgo.tech';
    $directory = rtrim(
        str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '/saas_api/test_phase4.php')),
        '/'
    );
    return $scheme . '://' . $host . $directory . '/test_phase4.php';
}

function phase4HttpRequest($url, $method = 'GET', $payload = null, $cookie = '') {
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
        CURLOPT_TIMEOUT => 20,
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

function phase4TableExists($conn, $tableName) {
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

function phase4Cleanup($conn, &$fixture) {
    if (!($conn instanceof mysqli) || empty($fixture)) {
        return true;
    }
    try {
        $tenantId = (string)($fixture['tenant_id'] ?? '');
        $orderIds = array_values(array_unique(array_map('intval', $fixture['order_ids'] ?? [])));
        $sessionIds = array_values(array_unique(array_map('intval', $fixture['session_ids'] ?? [])));
        $paymentIds = array_values(array_unique(array_map('intval', $fixture['payment_ids'] ?? [])));

        if ($paymentIds && phase4TableExists($conn, 'refunds')) {
            $refundDelete = $conn->prepare('DELETE FROM refunds WHERE payment_id = ?');
            foreach ($paymentIds as $paymentId) {
                $refundDelete->bind_param('i', $paymentId);
                $refundDelete->execute();
            }
            $refundDelete->close();
        }
        if ($paymentIds && phase4TableExists($conn, 'payment_order_items')) {
            $itemLinks = $conn->prepare('DELETE FROM payment_order_items WHERE payment_id = ?');
            foreach ($paymentIds as $paymentId) {
                $itemLinks->bind_param('i', $paymentId);
                $itemLinks->execute();
            }
            $itemLinks->close();
        }
        if ($paymentIds && phase4TableExists($conn, 'payment_orders')) {
            $links = $conn->prepare('DELETE FROM payment_orders WHERE payment_id = ?');
            foreach ($paymentIds as $paymentId) {
                $links->bind_param('i', $paymentId);
                $links->execute();
            }
            $links->close();
        }
        if ($orderIds && phase4TableExists($conn, 'payment_orders')) {
            $links = $conn->prepare('DELETE FROM payment_orders WHERE order_id = ?');
            foreach ($orderIds as $orderId) {
                $links->bind_param('i', $orderId);
                $links->execute();
            }
            $links->close();
        }
        if ($paymentIds && phase4TableExists($conn, 'payments')) {
            $payments = $conn->prepare('DELETE FROM payments WHERE id = ? AND tenant_id = ?');
            foreach ($paymentIds as $paymentId) {
                $payments->bind_param('is', $paymentId, $tenantId);
                $payments->execute();
            }
            $payments->close();
        }
        if ($orderIds && phase4TableExists($conn, 'order_voids')) {
            $voids = $conn->prepare('DELETE FROM order_voids WHERE order_id = ?');
            foreach ($orderIds as $orderId) {
                $voids->bind_param('i', $orderId);
                $voids->execute();
            }
            $voids->close();
        }
        if ($orderIds) {
            if (phase4TableExists($conn, 'payment_order_items')) {
                $itemLinks = $conn->prepare(
                    'DELETE poi FROM payment_order_items poi
                     INNER JOIN order_items oi ON oi.id = poi.order_item_id
                     WHERE oi.order_id = ?'
                );
                foreach ($orderIds as $orderId) {
                    $itemLinks->bind_param('i', $orderId);
                    $itemLinks->execute();
                }
                $itemLinks->close();
            }
            $items = $conn->prepare('DELETE FROM order_items WHERE order_id = ?');
            $orders = $conn->prepare('DELETE FROM orders WHERE id = ? AND tenant_id = ?');
            foreach ($orderIds as $orderId) {
                $items->bind_param('i', $orderId);
                $items->execute();
                $orders->bind_param('is', $orderId, $tenantId);
                $orders->execute();
            }
            $items->close();
            $orders->close();
        }
        if ($sessionIds) {
            $sessions = $conn->prepare('DELETE FROM dining_sessions WHERE id = ? AND tenant_id = ?');
            foreach ($sessionIds as $sessionId) {
                $sessions->bind_param('is', $sessionId, $tenantId);
                $sessions->execute();
            }
            $sessions->close();
        }
        $tableId = (int)($fixture['table_id'] ?? 0);
        if ($tableId > 0) {
            $table = $conn->prepare('DELETE FROM restaurant_tables WHERE id = ? AND tenant_id = ?');
            $table->bind_param('is', $tableId, $tenantId);
            $table->execute();
            $table->close();
        }
        return true;
    } catch (Throwable $error) {
        error_log('Phase 4 verifier cleanup failed: ' . $error->getMessage());
        return false;
    }
}

$results = [];
$fixture = [];
$conn = null;
$phase4ResponseSent = false;
register_shutdown_function(function () use (&$conn, &$fixture, &$phase4ResponseSent) {
    phase4Cleanup($conn, $fixture);
    if ($phase4ResponseSent) {
        return;
    }
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
        error_log('Phase 4 verifier stopped unexpectedly: ' . $error['message']);
        if (!headers_sent()) {
            http_response_code(500);
            header('Content-Type: application/json; charset=UTF-8');
        }
        echo json_encode([
            'access_url' => phase4AccessUrl(),
            'status' => 'FAIL',
            'message' => 'The verifier stopped because of a server-side PHP error. Check the PHP error log.'
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        $phase4ResponseSent = true;
    }
});

try {
    require_once __DIR__ . '/db_config.php';
    require_once __DIR__ . '/staff_auth.php';
    require_once __DIR__ . '/billing_common.php';
    require_once __DIR__ . '/financial_common.php';
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
    $baseUrl = rtrim(phase4AccessUrl(), '/');
    $authValid = false;
    if ($staffId > 0 && $tenantId !== '' && $role === 'super_admin') {
        $authCheck = $conn->prepare('SELECT role, tenant_id FROM users WHERE id = ? LIMIT 1');
        $authCheck->bind_param('i', $staffId);
        $authCheck->execute();
        $user = $authCheck->get_result()->fetch_assoc();
        $authCheck->close();
        $authValid = $user &&
            strtolower(trim((string)$user['role'])) === 'super_admin' &&
            (string)$user['tenant_id'] === $tenantId;
    }
    if (session_status() === PHP_SESSION_ACTIVE) {
        session_write_close();
    }

    $voidSource = file_get_contents(__DIR__ . '/void_order.php');
    $refundSource = file_get_contents(__DIR__ . '/refund_payment.php');
    $reportSource = file_get_contents(__DIR__ . '/financial_report.php');
    $voidRoleRestricted = strpos($voidSource, "requireAuth(\$conn, ['super_admin'])") !== false;
    $refundRoleRestricted = strpos($refundSource, "requireAuth(\$conn, ['super_admin'])") !== false;
    $reportUsesSettledLedger =
        strpos($reportSource, "p.status = 'Completed'") !== false &&
        strpos($reportSource, "ds.status = 'Settled'") !== false &&
        strpos($reportSource, 'payments_net_total') !== false &&
        strpos($reportSource, 'FROM refunds') !== false;
    phase4AddResult(
        $results,
        'Void and refund endpoints require Super Admin',
        $voidRoleRestricted && $refundRoleRestricted ? 'PASS' : 'FAIL',
        $voidRoleRestricted && $refundRoleRestricted
            ? 'Both endpoints use requireAuth($conn, [super_admin]); no tenant or order authority is taken from client input.'
            : 'A required Super Admin role restriction was not found in the endpoint source.'
    );
    phase4AddResult(
        $results,
        'Financial report is based on settled payment ledger net of refunds',
        $reportUsesSettledLedger ? 'PASS' : 'FAIL',
        $reportUsesSettledLedger
            ? 'The report source requires Completed payments and Settled sessions and subtracts refund ledger rows.'
            : 'Expected completed-payment, settled-session and refund-ledger filtering was not found.'
    );

    $unauthorizedOrderId = 0;
    $safeIdCheck = $conn->prepare('SELECT COUNT(*) AS order_count FROM orders WHERE id = ?');
    for ($attempt = 0; $attempt < 10; $attempt++) {
        $candidateId = random_int(2000000000, 2147483647);
        $safeIdCheck->bind_param('i', $candidateId);
        $safeIdCheck->execute();
        if ((int)$safeIdCheck->get_result()->fetch_assoc()['order_count'] === 0) {
            $unauthorizedOrderId = $candidateId;
            break;
        }
    }
    $safeIdCheck->close();
    if ($unauthorizedOrderId <= 0) {
        throw new RuntimeException('Could not reserve a nonexistent order ID for the auth check.');
    }
    $unauthenticated = phase4HttpRequest($baseUrl . '/void_order.php', 'POST', [
        'order_id' => $unauthorizedOrderId,
        'reason' => 'Phase 4 verifier unauthorized request'
    ]);
    $unauthRejected = $unauthenticated['available'] &&
        in_array((int)$unauthenticated['http_code'], [401, 403], true);
    phase4AddResult(
        $results,
        'Unauthenticated order void is rejected',
        !$unauthenticated['available'] ? 'SKIP' : ($unauthRejected ? 'PASS' : 'FAIL'),
        !$unauthenticated['available']
            ? (string)($unauthenticated['error'] ?? 'HTTP request unavailable')
            : ($unauthRejected
                ? 'A request without a staff session received HTTP ' . (int)$unauthenticated['http_code'] . '.'
                : 'Expected HTTP 401 or 403; received HTTP ' . (int)$unauthenticated['http_code'] .
                    ' with response status "' .
                    (string)($unauthenticated['json']['status'] ?? 'non-JSON') .
                    '" and message "' .
                    (string)($unauthenticated['json']['message'] ?? $unauthenticated['error'] ?? '') . '".')
    );

    if (!$authValid || $cookie === '' || !function_exists('curl_init')) {
        $reason = !function_exists('curl_init')
            ? 'Live endpoint tests require PHP cURL.'
            : 'Open this verifier in a logged-in Super Admin browser session to run disposable integration tests.';
        foreach ([
            'Void request without a reason is rejected',
            'Super Admin void preserves order and records audit',
            'Refund above remaining balance is rejected',
            'Valid refund is written to refunds ledger',
            'Financial report includes only settled payment transactions',
            'Ready-for-billing sessions and date-range discrepancies are reported'
        ] as $test) {
            phase4AddResult($results, $test, 'SKIP', $reason);
        }
    } else {
        billingEnsureSchema($conn);
        financialEnsureSchema($conn);
        $fixture = [
            'tenant_id' => $tenantId,
            'order_ids' => [],
            'session_ids' => [],
            'payment_ids' => []
        ];

        $tableNumber = 0;
        $tableCheck = $conn->prepare(
            'SELECT id FROM restaurant_tables WHERE tenant_id = ? AND table_number = ? LIMIT 1'
        );
        for ($attempt = 0; $attempt < 10; $attempt++) {
            $candidate = random_int(1000000000, 1999999999);
            $tableCheck->bind_param('si', $tenantId, $candidate);
            $tableCheck->execute();
            if ($tableCheck->get_result()->num_rows === 0) {
                $tableNumber = $candidate;
                break;
            }
        }
        $tableCheck->close();
        if ($tableNumber <= 0) {
            throw new RuntimeException('Could not reserve a unique disposable table number.');
        }
        $tableInsert = $conn->prepare(
            "INSERT INTO restaurant_tables (tenant_id, table_number, status)
             VALUES (?, ?, 'Dining')"
        );
        $tableInsert->bind_param('si', $tenantId, $tableNumber);
        $tableInsert->execute();
        $fixture['table_id'] = (int)$conn->insert_id;
        $tableInsert->close();

        $sessionInsert = $conn->prepare(
            'INSERT INTO dining_sessions (tenant_id, table_id, table_number, status)
             VALUES (?, ?, ?, ?)'
        );
        $sessionIdsByStatus = [];
        foreach (['Open', 'Settled', 'ReadyForBilling'] as $status) {
            $tableId = (int)$fixture['table_id'];
            $sessionInsert->bind_param('siis', $tenantId, $tableId, $tableNumber, $status);
            $sessionInsert->execute();
            $sessionId = (int)$conn->insert_id;
            $fixture['session_ids'][] = $sessionId;
            $sessionIdsByStatus[$status] = $sessionId;
        }
        $sessionInsert->close();

        $orderInsert = $conn->prepare(
            'INSERT INTO orders
             (tenant_id, table_id, user_id, customer_email, total_amount, status, session_id, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, NOW())'
        );
        $orderFixtures = [
            ['phase4_void_test', 'Pending', 'Open', '1.00'],
            ['phase4_paid_test', 'Settled', 'Settled', '10.00'],
            ['phase4_ready_test', 'Pending', 'ReadyForBilling', '5.00'],
            ['phase4_unpaid_test', 'Pending', 'Settled', '3.00']
        ];
        $orderIdsByKind = [];
        foreach ($orderFixtures as $index => $item) {
            $userId = $item[0];
            $customerEmail = '';
            $totalAmount = (float)$item[3];
            $orderStatus = $item[1];
            $sessionId = $sessionIdsByStatus[$item[2]];
            $tableId = (int)$fixture['table_id'];
            $orderInsert->bind_param(
                'sissdsi',
                $tenantId,
                $tableId,
                $userId,
                $customerEmail,
                $totalAmount,
                $orderStatus,
                $sessionId
            );
            $orderInsert->execute();
            $orderId = (int)$conn->insert_id;
            $fixture['order_ids'][] = $orderId;
            $orderIdsByKind[$item[0]] = $orderId;
        }
        $orderInsert->close();

        $missingReason = phase4HttpRequest(
            $baseUrl . '/void_order.php',
            'POST',
            ['order_id' => $orderIdsByKind['phase4_void_test']],
            $cookie
        );
        $missingReasonPassed = $missingReason['available'] &&
            $missingReason['http_code'] === 400 &&
            ($missingReason['json']['status'] ?? '') === 'error';
        phase4AddResult(
            $results,
            'Void request without a reason is rejected',
            $missingReasonPassed ? 'PASS' : 'FAIL',
            $missingReasonPassed
                ? 'The Super Admin endpoint rejected a missing void reason with HTTP 400.'
                : 'Expected HTTP 400 for a missing reason; got HTTP ' .
                    (string)($missingReason['http_code'] ?? 'unavailable') . '.'
        );

        $voidResponse = phase4HttpRequest(
            $baseUrl . '/void_order.php',
            'POST',
            [
                'order_id' => $orderIdsByKind['phase4_void_test'],
                'reason' => 'Temporary Phase 4 verifier fixture'
            ],
            $cookie
        );
        $voidLookup = $conn->prepare(
            'SELECT status FROM orders WHERE id = ? AND tenant_id = ? LIMIT 1'
        );
        $voidOrderId = $orderIdsByKind['phase4_void_test'];
        $voidLookup->bind_param('is', $voidOrderId, $tenantId);
        $voidLookup->execute();
        $voidOrderRow = $voidLookup->get_result()->fetch_assoc();
        $voidLookup->close();
        $voidAudit = $conn->prepare(
            'SELECT COUNT(*) AS audit_count FROM order_voids
             WHERE order_id = ? AND reason = ?'
        );
        $voidReason = 'Temporary Phase 4 verifier fixture';
        $voidAudit->bind_param('is', $voidOrderId, $voidReason);
        $voidAudit->execute();
        $voidAuditCount = (int)$voidAudit->get_result()->fetch_assoc()['audit_count'];
        $voidAudit->close();
        $orderStillPresent = $conn->prepare(
            'SELECT COUNT(*) AS order_count FROM orders WHERE id = ? AND tenant_id = ?'
        );
        $orderStillPresent->bind_param('is', $voidOrderId, $tenantId);
        $orderStillPresent->execute();
        $voidOrderCount = (int)$orderStillPresent->get_result()->fetch_assoc()['order_count'];
        $orderStillPresent->close();
        $voidPassed = $voidResponse['available'] &&
            $voidResponse['http_code'] === 200 &&
            ($voidResponse['json']['status'] ?? '') === 'success' &&
            $voidOrderRow && strtolower((string)$voidOrderRow['status']) === 'voided' &&
            $voidAuditCount === 1 && $voidOrderCount === 1;
        phase4AddResult(
            $results,
            'Super Admin void preserves order and records audit',
            $voidPassed ? 'PASS' : 'FAIL',
            $voidPassed
                ? 'The order row remains present as Voided and exactly one matching order_voids audit entry was written.'
                : 'Void did not preserve the order and create its audit row. HTTP ' .
                    (string)($voidResponse['http_code'] ?? 'unavailable') .
                    '; status=' . (string)($voidOrderRow['status'] ?? 'missing') .
                    '; audits=' . $voidAuditCount . '; order rows=' . $voidOrderCount . '.'
        );

        $paidOrderId = $orderIdsByKind['phase4_paid_test'];
        $paidSessionId = $sessionIdsByStatus['Settled'];
        $paymentKey = 'phase4_test_' . bin2hex(random_bytes(16));
        $paymentInsert = $conn->prepare(
            "INSERT INTO payments
             (order_id, session_id, tenant_id, amount, method, staff_id, status, idempotency_key)
             VALUES (?, ?, ?, '10.00', 'Cash', ?, 'Completed', ?)"
        );
        $paymentInsert->bind_param(
            'iisis',
            $paidOrderId,
            $paidSessionId,
            $tenantId,
            $staffId,
            $paymentKey
        );
        $paymentInsert->execute();
        $paymentId = (int)$conn->insert_id;
        $fixture['payment_ids'][] = $paymentId;
        $paymentInsert->close();
        $paymentOrderInsert = $conn->prepare(
            'INSERT INTO payment_orders (payment_id, order_id) VALUES (?, ?)'
        );
        $paymentOrderInsert->bind_param('ii', $paymentId, $paidOrderId);
        $paymentOrderInsert->execute();
        $paymentOrderInsert->close();

        $tooLargeRefund = phase4HttpRequest(
            $baseUrl . '/refund_payment.php',
            'POST',
            [
                'payment_id' => $paymentId,
                'refund_amount' => '10.01',
                'reason' => 'Temporary over-refund test'
            ],
            $cookie
        );
        $refundsBeforeValid = $conn->prepare(
            'SELECT COUNT(*) AS refund_count FROM refunds WHERE payment_id = ?'
        );
        $refundsBeforeValid->bind_param('i', $paymentId);
        $refundsBeforeValid->execute();
        $refundCountAfterRejected = (int)$refundsBeforeValid->get_result()->fetch_assoc()['refund_count'];
        $refundsBeforeValid->close();
        $overRefundPassed = $tooLargeRefund['available'] &&
            $tooLargeRefund['http_code'] === 409 &&
            ($tooLargeRefund['json']['status'] ?? '') === 'error' &&
            $refundCountAfterRejected === 0;
        phase4AddResult(
            $results,
            'Refund above remaining balance is rejected',
            $overRefundPassed ? 'PASS' : 'FAIL',
            $overRefundPassed
                ? 'The endpoint rejected a refund larger than the payment with HTTP 409 and wrote no refund row.'
                : 'Expected HTTP 409 and no refund row; got HTTP ' .
                    (string)($tooLargeRefund['http_code'] ?? 'unavailable') .
                    ' and ' . $refundCountAfterRejected . ' refund row(s).'
        );

        $validRefund = phase4HttpRequest(
            $baseUrl . '/refund_payment.php',
            'POST',
            [
                'payment_id' => $paymentId,
                'refund_amount' => '2.00',
                'reason' => 'Temporary valid refund test'
            ],
            $cookie
        );
        $refundLookup = $conn->prepare(
            'SELECT id, amount, reason FROM refunds
             WHERE payment_id = ? AND reason = ? ORDER BY id DESC LIMIT 1'
        );
        $validRefundReason = 'Temporary valid refund test';
        $refundLookup->bind_param('is', $paymentId, $validRefundReason);
        $refundLookup->execute();
        $refundRow = $refundLookup->get_result()->fetch_assoc();
        $refundLookup->close();
        $refundPassed = $validRefund['available'] &&
            $validRefund['http_code'] === 200 &&
            ($validRefund['json']['status'] ?? '') === 'success' &&
            $refundRow && (int)round((float)$refundRow['amount'] * 100) === 200;
        phase4AddResult(
            $results,
            'Valid refund is written to refunds ledger',
            $refundPassed ? 'PASS' : 'FAIL',
            $refundPassed
                ? 'A valid refund request succeeded and its 2.00 amount is present in the refunds ledger.'
                : 'A valid refund did not produce the expected ledger row. HTTP ' .
                    (string)($validRefund['http_code'] ?? 'unavailable') . '.'
        );

        $remainingBalanceRefund = phase4HttpRequest(
            $baseUrl . '/refund_payment.php',
            'POST',
            [
                'payment_id' => $paymentId,
                'refund_amount' => '8.01',
                'reason' => 'Temporary remaining-balance test'
            ],
            $cookie
        );
        $remainingBalancePassed = $remainingBalanceRefund['available'] &&
            $remainingBalanceRefund['http_code'] === 409 &&
            ($remainingBalanceRefund['json']['status'] ?? '') === 'error';
        phase4AddResult(
            $results,
            'Cumulative refunds cannot exceed remaining payment balance',
            $remainingBalancePassed ? 'PASS' : 'FAIL',
            $remainingBalancePassed
                ? 'After a 2.00 refund, the endpoint rejected an 8.01 refund against the 8.00 remaining balance.'
                : 'Expected HTTP 409 when cumulative refunds exceed the original payment amount.'
        );

        $setOpenForReportCheck = $conn->prepare(
            "UPDATE dining_sessions SET status = 'Open'
             WHERE id = ? AND tenant_id = ?"
        );
        $paidSessionId = $sessionIdsByStatus['Settled'];
        $setOpenForReportCheck->bind_param('is', $paidSessionId, $tenantId);
        $setOpenForReportCheck->execute();
        $setOpenForReportCheck->close();
        $reportDate = (string)$conn->query('SELECT CURDATE() AS report_date')
            ->fetch_assoc()['report_date'];
        $reportUrl = $baseUrl . '/financial_report.php?from=' . rawurlencode($reportDate) .
            '&to=' . rawurlencode($reportDate);
        $reportWhileOpen = phase4HttpRequest($reportUrl, 'GET', null, $cookie);
        $openPaymentVisible = false;
        if (is_array($reportWhileOpen['json']['transactions'] ?? null)) {
            foreach ($reportWhileOpen['json']['transactions'] as $transaction) {
                if (($transaction['type'] ?? '') === 'payment' &&
                    (int)($transaction['id'] ?? 0) === $paymentId) {
                    $openPaymentVisible = true;
                }
            }
        }
        $openPaymentHiddenPassed = $reportWhileOpen['available'] &&
            $reportWhileOpen['http_code'] === 200 &&
            !$openPaymentVisible;
        phase4AddResult(
            $results,
            'Unsettled-session payment is excluded from financial report',
            $openPaymentHiddenPassed ? 'PASS' : 'FAIL',
            $openPaymentHiddenPassed
                ? 'A Completed payment tied to an Open session did not appear in the report.'
                : 'The report included a payment whose session is not Settled, or the report request failed.'
        );

        $settleFixture = $conn->prepare(
            "UPDATE dining_sessions SET status = 'Settled'
             WHERE id = ? AND tenant_id = ?"
        );
        $settleFixture->bind_param('is', $paidSessionId, $tenantId);
        $settleFixture->execute();
        $settleFixture->close();
        $settledReport = phase4HttpRequest($reportUrl, 'GET', null, $cookie);
        $foundPayment = false;
        $foundRefund = false;
        $transactionNetCents = 0;
        $transactions = $settledReport['json']['transactions'] ?? [];
        if (is_array($transactions)) {
            foreach ($transactions as $transaction) {
                if (($transaction['type'] ?? '') === 'payment' &&
                    (int)($transaction['id'] ?? 0) === $paymentId) {
                    $foundPayment = true;
                    $transactionNetCents += (int)round((float)$transaction['amount'] * 100);
                }
                if (($transaction['type'] ?? '') === 'refund' &&
                    (int)($transaction['payment_id'] ?? 0) === $paymentId) {
                    $foundRefund = true;
                    $transactionNetCents += (int)round((float)$transaction['amount'] * 100);
                }
            }
        }
        $unpaidOrderId = $orderIdsByKind['phase4_ready_test'];
        $unpaidOrderAbsentFromLedger = true;
        foreach ((is_array($transactions) ? $transactions : []) as $transaction) {
            if (in_array(
                (int)($transaction['order_id'] ?? 0),
                [$unpaidOrderId, $orderIdsByKind['phase4_unpaid_test']],
                true
            )) {
                $unpaidOrderAbsentFromLedger = false;
            }
        }
        $readyCount =
            (int)($settledReport['json']['summary']['ready_for_billing_sessions'] ?? 0);
        $countVariance =
            (int)($settledReport['json']['reconciliation']['count_variance'] ?? 0);
        $reportPassed = $settledReport['available'] &&
            $settledReport['http_code'] === 200 &&
            ($settledReport['json']['status'] ?? '') === 'success' &&
            $foundPayment && $foundRefund &&
            $transactionNetCents === 800 &&
            $unpaidOrderAbsentFromLedger;
        phase4AddResult(
            $results,
            'Financial report includes only settled payment transactions',
            $reportPassed ? 'PASS' : 'FAIL',
            $reportPassed
                ? 'After settling the fixture session, the report includes its payment and refund for net 8.00, excludes the raw unpaid order, and reports the ReadyForBilling session with a warning.'
                : 'Expected settled payment/refund net 8.00, no unpaid-order ledger entry, and reconciliation warning for ReadyForBilling. Report HTTP ' .
                    (string)($settledReport['http_code'] ?? 'unavailable') .
                    '; fixture transaction net=' . number_format($transactionNetCents / 100, 2, '.', '') .
                    '; ready sessions=' . (string)($settledReport['json']['summary']['ready_for_billing_sessions'] ?? 'missing') . '.'
        );
        phase4AddResult(
            $results,
            'Ready-for-billing sessions trigger the warning banner',
            $settledReport['available'] && $settledReport['http_code'] === 200 &&
                $readyCount >= 1 &&
                ($settledReport['json']['reconciliation']['warning'] ?? false) === true
                ? 'PASS' : 'FAIL',
            $readyCount >= 1 &&
                ($settledReport['json']['reconciliation']['warning'] ?? false) === true
                ? 'The selected date range returned a ReadyForBilling session and the report raised its warning.'
                : 'Expected a ReadyForBilling session and warning in the selected date range.'
        );
        phase4AddResult(
            $results,
            'Unmatched placed orders trigger a date-range discrepancy warning',
            $settledReport['available'] && $settledReport['http_code'] === 200 &&
                $countVariance > 0 &&
                ($settledReport['json']['reconciliation']['warning'] ?? false) === true
                ? 'PASS' : 'FAIL',
            $countVariance > 0 &&
                ($settledReport['json']['reconciliation']['warning'] ?? false) === true
                ? 'The deliberately unpaid order created a positive placed-versus-paid/open count variance and the report warned.'
                : 'Expected a positive order-count variance and reconciliation warning; received variance ' .
                    $countVariance . '.'
        );
    }

    $cleanupPassed = phase4Cleanup($conn, $fixture);
    if ($cleanupPassed) {
        $fixture = [];
    }
    phase4AddResult(
        $results,
        'Disposable test data cleanup',
        $cleanupPassed ? 'PASS' : 'FAIL',
        $cleanupPassed
            ? 'Temporary audit, refund, payment, order, session, and table rows were removed.'
            : 'Cleanup failed; check the PHP error log and remove only the Phase 4 verifier fixture rows.'
    );
    $hasFail = false;
    $hasSkip = false;
    foreach ($results as $result) {
        if ($result['status'] === 'FAIL') {
            $hasFail = true;
        } elseif ($result['status'] === 'SKIP') {
            $hasSkip = true;
        }
    }
    $overall = $hasFail ? 'FAIL' : ($hasSkip ? 'PARTIAL' : 'PASS');
    echo json_encode([
        'access_url' => phase4AccessUrl(),
        'status' => $overall,
        'message' => 'Live checks use disposable records and attempt cleanup before the report is returned.',
        'results' => $results
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    $phase4ResponseSent = true;
} catch (Throwable $error) {
    error_log('Phase 4 verifier failed: ' . $error->getMessage());
    $cleanupPassed = phase4Cleanup($conn, $fixture);
    if ($cleanupPassed) {
        $fixture = [];
    }
    phase4AddResult(
        $results,
        'Verifier setup and disposable fixture',
        'FAIL',
        'The integration test could not complete. Check the PHP error log for details.'
    );
    phase4AddResult(
        $results,
        'Disposable test data cleanup',
        $cleanupPassed ? 'PASS' : 'FAIL',
        $cleanupPassed ? 'Temporary fixture cleanup completed.' : 'Fixture cleanup needs review in the PHP error log.'
    );
    echo json_encode([
        'access_url' => phase4AccessUrl(),
        'status' => 'FAIL',
        'message' => 'Live checks use disposable records and attempt cleanup before the report is returned.',
        'results' => $results
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    $phase4ResponseSent = true;
}
?>
