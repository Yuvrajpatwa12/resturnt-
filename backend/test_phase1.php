<?php
header('Content-Type: application/json; charset=UTF-8');

function phase1TestAdd(&$results, $name, $status, $message) {
    $results[] = [
        'test' => $name,
        'status' => $status,
        'message' => $message
    ];
}

function phase1TestJson($status, $message) {
    echo json_encode([
        'access_url' => 'https://startupsgo.tech/saas_api/test_phase1.php',
        'status' => $status,
        'message' => $message
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    exit;
}

function phase1TestHttpPost($url, $payload, $cookie = null) {
    if (!function_exists('curl_init')) {
        return ['available' => false, 'error' => 'PHP cURL extension is unavailable'];
    }

    $curl = curl_init($url);
    if ($curl === false) {
        return ['available' => false, 'error' => 'Could not initialize cURL'];
    }

    $headers = ['Content-Type: application/json'];
    if ($cookie !== null && $cookie !== '') {
        $headers[] = 'Cookie: ' . $cookie;
    }

    curl_setopt_array($curl, [
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($payload),
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT => 12,
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

function phase1TestSettleUrl() {
    return 'https://startupsgo.tech/saas_api/settle_bill.php';
}

$results = [];
$testPaymentKey = null;
$testPaymentId = null;
$conn = null;

register_shutdown_function(function () use (&$conn, &$testPaymentKey) {
    if ($conn instanceof mysqli && $testPaymentKey !== null) {
        try {
            $cleanup = $conn->prepare('DELETE FROM payments WHERE idempotency_key = ?');
            $cleanup->bind_param('s', $testPaymentKey);
            $cleanup->execute();
            $cleanup->close();
        } catch (Throwable $error) {
            error_log('Phase 1 test cleanup failed: ' . $error->getMessage());
        }
    }
});

try {
    require_once __DIR__ . '/db_config.php';
    if (is_file(__DIR__ . '/staff_auth.php')) {
        require_once __DIR__ . '/staff_auth.php';
    }
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
    if (!isset($conn) || !($conn instanceof mysqli) || $conn->connect_error) {
        phase1TestJson('FAIL', 'Could not connect to the configured MySQL database.');
    }

    $authHelperAvailable = function_exists('requireAuth');
    phase1TestAdd(
        $results,
        'Staff authentication helper is loaded',
        $authHelperAvailable ? 'PASS' : 'FAIL',
        $authHelperAvailable
            ? 'The verifier loaded a requireAuth() helper.'
            : 'No requireAuth() helper was loaded. Deploy staff_auth.php with settle_bill.php; settlement must remain disabled until server-side authentication is available.'
    );

    $currentStaff = isset($_SESSION['staff']) && is_array($_SESSION['staff'])
        ? $_SESSION['staff']
        : [];
    $currentRole = strtolower(trim((string)($currentStaff['role'] ?? '')));
    $currentTenantId = trim((string)($currentStaff['tenant_id'] ?? ''));
    $currentStaffId = (int)($currentStaff['id'] ?? 0);
    $currentCookie = isset($_SERVER['HTTP_COOKIE']) ? $_SERVER['HTTP_COOKIE'] : '';
    if (session_status() === PHP_SESSION_ACTIVE) {
        session_write_close();
    }
    $endpointUrl = phase1TestSettleUrl();

    $preflightTableCheck = $conn->prepare(
        'SELECT COUNT(*) AS table_count
         FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?'
    );
    $preflightTableName = 'payments';
    $preflightTableCheck->bind_param('s', $preflightTableName);
    $preflightTableCheck->execute();
    $paymentsTableInitiallyExists =
        (int)$preflightTableCheck->get_result()->fetch_assoc()['table_count'] > 0;
    $preflightTableCheck->close();

    $schemaBootstrapStatus = 'SKIP';
    $schemaBootstrapMessage = 'The payments table already exists; no initialization request was needed.';
    if (!$paymentsTableInitiallyExists) {
        $schemaBootstrapMessage = 'The payments table is missing. Sign in as an admin/cashier in this browser to safely initialize it through settle_bill.php.';
        if (in_array($currentRole, ['admin', 'cashier'], true) &&
            $currentStaffId > 0 &&
            $currentTenantId !== '' &&
            $currentCookie !== '' &&
            function_exists('curl_init')) {
            try {
                $candidateOrderId = 0;
                $orderExistsCheck = $conn->prepare(
                    'SELECT id FROM orders WHERE tenant_id = ? AND id = ? LIMIT 1'
                );
                for ($attempt = 0; $attempt < 5; $attempt++) {
                    $candidateOrderId = random_int(1500000000, 2100000000);
                    $orderExistsCheck->bind_param('si', $currentTenantId, $candidateOrderId);
                    $orderExistsCheck->execute();
                    if ($orderExistsCheck->get_result()->num_rows === 0) {
                        break;
                    }
                    $candidateOrderId = 0;
                }
                $orderExistsCheck->close();

                if ($candidateOrderId > 0) {
                    $bootstrapResponse = phase1TestHttpPost($endpointUrl, [
                        'tenant_id' => $currentTenantId,
                        'order_ids' => [$candidateOrderId],
                        'amount' => '0.01',
                        'method' => 'Phase1 schema bootstrap check',
                        'idempotency_key' => 'phase1_schema_' . bin2hex(random_bytes(16))
                    ], $currentCookie);

                    if ($bootstrapResponse['available'] &&
                        $bootstrapResponse['http_code'] === 404) {
                        $schemaBootstrapStatus = 'PASS';
                        $schemaBootstrapMessage = 'The authenticated settlement endpoint created its schema, then correctly rejected a verified non-existent test order; no payment or order was changed.';
                    } else {
                        $httpCode = $bootstrapResponse['http_code'] ?? 'unavailable';
                        $endpointMessage = $bootstrapResponse['json']['message'] ?? '';
                        $schemaBootstrapStatus = 'FAIL';
                        $schemaBootstrapMessage = 'Schema initialization did not reach the expected missing-order response (HTTP ' .
                            $httpCode . '). ' . (string)$endpointMessage;
                    }
                } else {
                    $schemaBootstrapStatus = 'FAIL';
                    $schemaBootstrapMessage = 'Could not reserve a non-existent order ID safely; no endpoint request was made.';
                }
            } catch (Throwable $error) {
                error_log('Phase 1 schema bootstrap failed: ' . $error->getMessage());
                $schemaBootstrapStatus = 'FAIL';
                $schemaBootstrapMessage = 'The safe schema bootstrap request failed. Check the endpoint response and PHP error log.';
            }
        }
    }
    phase1TestAdd(
        $results,
        'Payment schema initialization',
        $schemaBootstrapStatus,
        $schemaBootstrapMessage
    );

    $databaseResult = $conn->query('SELECT DATABASE() AS database_name');
    $databaseRow = $databaseResult->fetch_assoc();
    $databaseName = isset($databaseRow['database_name']) ? $databaseRow['database_name'] : '';
    if ($databaseName === '') {
        phase1TestJson('FAIL', 'The active MySQL database could not be determined.');
    }

    $tableCheck = $conn->prepare(
        'SELECT COUNT(*) AS table_count
         FROM information_schema.TABLES
         WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?'
    );
    $tableName = 'payments';
    $tableCheck->bind_param('ss', $databaseName, $tableName);
    $tableCheck->execute();
    $paymentsTableExists = (int)$tableCheck->get_result()->fetch_assoc()['table_count'] > 0;
    $tableCheck->close();
    phase1TestAdd(
        $results,
        'Payments table exists',
        $paymentsTableExists ? 'PASS' : 'FAIL',
        $paymentsTableExists
            ? 'The payments table exists in the active database.'
            : 'The payments table is missing; settle_bill.php must be deployed and its schema created.'
    );

    $requiredColumns = [
        'id',
        'order_id',
        'session_id',
        'tenant_id',
        'amount',
        'method',
        'staff_id',
        'status',
        'idempotency_key',
        'created_at'
    ];
    $actualColumns = [];
    if ($paymentsTableExists) {
        $columnCheck = $conn->prepare(
            'SELECT COLUMN_NAME
             FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?'
        );
        $columnCheck->bind_param('ss', $databaseName, $tableName);
        $columnCheck->execute();
        $columnRows = $columnCheck->get_result();
        while ($columnRow = $columnRows->fetch_assoc()) {
            $actualColumns[] = $columnRow['COLUMN_NAME'];
        }
        $columnCheck->close();
    }
    $missingColumns = array_values(array_diff($requiredColumns, $actualColumns));
    phase1TestAdd(
        $results,
        'Required payment columns',
        !$paymentsTableExists
            ? 'SKIP'
            : (count($missingColumns) === 0 ? 'PASS' : 'FAIL'),
        !$paymentsTableExists
            ? 'Cannot inspect columns because payments does not exist.'
            : (count($missingColumns) === 0
                ? 'All required payment columns are present.'
                : 'Missing columns: ' . implode(', ', $missingColumns))
    );

    $uniqueIdempotencyIndex = false;
    if ($paymentsTableExists) {
        $indexCheck = $conn->prepare(
            'SELECT INDEX_NAME, COUNT(*) AS column_count,
                    SUM(CASE WHEN COLUMN_NAME = ? THEN 1 ELSE 0 END) AS key_column_count
             FROM information_schema.STATISTICS
             WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND NON_UNIQUE = 0
             GROUP BY INDEX_NAME'
        );
        $idempotencyColumn = 'idempotency_key';
        $indexCheck->bind_param('sss', $idempotencyColumn, $databaseName, $tableName);
        $indexCheck->execute();
        $indexRows = $indexCheck->get_result();
        while ($indexRow = $indexRows->fetch_assoc()) {
            if ((int)$indexRow['column_count'] === 1 &&
                (int)$indexRow['key_column_count'] === 1) {
                $uniqueIdempotencyIndex = true;
                break;
            }
        }
        $indexCheck->close();
    }
    phase1TestAdd(
        $results,
        'Unique idempotency_key constraint',
        !$paymentsTableExists
            ? 'SKIP'
            : ($uniqueIdempotencyIndex ? 'PASS' : 'FAIL'),
        !$paymentsTableExists
            ? 'Cannot inspect the unique index because payments does not exist.'
            : ($uniqueIdempotencyIndex
                ? 'idempotency_key has a single-column UNIQUE index.'
                : 'No single-column UNIQUE index exists for idempotency_key.')
    );

    $settleFile = __DIR__ . '/settle_bill.php';
    $settleSource = is_file($settleFile) ? file_get_contents($settleFile) : false;
    $normalizedSource = $settleSource === false
        ? ''
        : preg_replace('/\s+/', ' ', $settleSource);
    $authAllowListPresent = strpos(
        $normalizedSource,
        "requireAuth(\$conn, ['admin', 'cashier'])"
    ) !== false;
    $explicitRoleRejectionPresent = strpos(
        $normalizedSource,
        "!in_array(" . '$role' . ", ['admin', 'cashier'], true)"
    ) !== false;
    $sourceHasRoleGuard = $authAllowListPresent && $explicitRoleRejectionPresent;
    phase1TestAdd(
        $results,
        'Admin/cashier endpoint role allow-list',
        $sourceHasRoleGuard ? 'PASS' : 'FAIL',
        $sourceHasRoleGuard
            ? 'settle_bill.php passes only admin/cashier to requireAuth and explicitly rejects roles outside that allow-list (source check).'
            : 'Could not verify the required admin/cashier allow-list and explicit role rejection in settle_bill.php.'
    );

    $anonymousResponse = phase1TestHttpPost($endpointUrl, [
        'order_ids' => [],
        'amount' => '0.01',
        'method' => 'Phase1 verification',
        'idempotency_key' => 'phase1_no_auth_' . bin2hex(random_bytes(12))
    ]);
    $anonymousRejected = $anonymousResponse['available'] &&
        in_array($anonymousResponse['http_code'], [401, 403], true);
    phase1TestAdd(
        $results,
        'Settlement rejects request without session/token',
        !$anonymousResponse['available'] ? 'SKIP' : ($anonymousRejected ? 'PASS' : 'FAIL'),
        !$anonymousResponse['available']
            ? 'Could not make the internal HTTP request: ' . $anonymousResponse['error']
            : ($anonymousRejected
                ? 'An unauthenticated POST was rejected with HTTP ' . $anonymousResponse['http_code'] . '.'
                : 'Expected HTTP 401 or 403, received HTTP ' . $anonymousResponse['http_code'] .
                    (isset($anonymousResponse['json']['message'])
                        ? ' Endpoint message: ' . $anonymousResponse['json']['message']
                        : (isset($anonymousResponse['body'])
                            ? ' Response: ' . substr(strip_tags($anonymousResponse['body']), 0, 240)
                            : '')))
    );

    $roleWaiterDenied = $sourceHasRoleGuard &&
        !in_array('waiter', ['admin', 'cashier'], true);
    phase1TestAdd(
        $results,
        'Waiter role is denied',
        $roleWaiterDenied ? 'PASS' : 'FAIL',
        $roleWaiterDenied
            ? 'The verified source allow-list excludes waiter and the endpoint has an explicit non-allow-listed-role rejection. This is a source/logic check; no live waiter session was available.'
            : 'Could not verify that waiter is rejected by the endpoint role guard.'
    );

    $isAuthorizedSession = in_array($currentRole, ['admin', 'cashier'], true) &&
        $currentStaffId > 0 && $currentTenantId !== '' && $currentCookie !== '';
    $liveRoleStatus = 'SKIP';
    $liveRoleMessage = 'Open this verifier in an authenticated admin/cashier browser session with the PHP cURL extension enabled to test the live session.';
    $idempotencyStatus = 'SKIP';
    $idempotencyMessage = 'Open this verifier in an authenticated admin/cashier browser session with the PHP cURL extension enabled to run the disposable replay test.';

    if ($isAuthorizedSession &&
        function_exists('curl_init') &&
        $paymentsTableExists &&
        count($missingColumns) === 0 &&
        $uniqueIdempotencyIndex) {
        try {
            $testPaymentKey = 'phase1test_' . bin2hex(random_bytes(20));
            $testAmount = '0.01';
            $testMethod = 'Phase1 disposable replay check';
            $testStatus = 'Completed';
            $testOrderId = null;
            $testSessionId = null;

            $fixture = $conn->prepare(
                'INSERT INTO payments
                    (order_id, session_id, tenant_id, amount, method, staff_id, status, idempotency_key)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
            );
            $fixture->bind_param(
                'iisssiss',
                $testOrderId,
                $testSessionId,
                $currentTenantId,
                $testAmount,
                $testMethod,
                $currentStaffId,
                $testStatus,
                $testPaymentKey
            );
            $fixture->execute();
            $testPaymentId = (int)$conn->insert_id;
            $fixture->close();

            $replayPayload = [
                'tenant_id' => $currentTenantId,
                'order_ids' => [2147483647],
                'amount' => $testAmount,
                'method' => $testMethod,
                'idempotency_key' => $testPaymentKey
            ];
            $firstReplay = phase1TestHttpPost($endpointUrl, $replayPayload, $currentCookie);
            $secondReplay = phase1TestHttpPost($endpointUrl, $replayPayload, $currentCookie);
            $firstJson = isset($firstReplay['json']) && is_array($firstReplay['json'])
                ? $firstReplay['json']
                : [];
            $secondJson = isset($secondReplay['json']) && is_array($secondReplay['json'])
                ? $secondReplay['json']
                : [];

            $countCheck = $conn->prepare(
                'SELECT COUNT(*) AS payment_count FROM payments WHERE idempotency_key = ?'
            );
            $countCheck->bind_param('s', $testPaymentKey);
            $countCheck->execute();
            $fixtureCount = (int)$countCheck->get_result()->fetch_assoc()['payment_count'];
            $countCheck->close();

            $idempotencyPassed =
                $firstReplay['available'] && $secondReplay['available'] &&
                $firstReplay['http_code'] === 200 && $secondReplay['http_code'] === 200 &&
                !empty($firstJson['idempotent_replay']) &&
                !empty($secondJson['idempotent_replay']) &&
                isset($firstJson['payment_id'], $secondJson['payment_id']) &&
                (int)$firstJson['payment_id'] === $testPaymentId &&
                (int)$secondJson['payment_id'] === $testPaymentId &&
                $fixtureCount === 1;

            $liveRoleAccepted = $firstReplay['available'] &&
                $firstReplay['http_code'] === 200 &&
                !empty($firstJson['idempotent_replay']) &&
                (int)($firstJson['payment_id'] ?? 0) === $testPaymentId;
            $liveRoleStatus = $liveRoleAccepted ? 'PASS' : 'FAIL';
            $liveRoleMessage = $liveRoleAccepted
                ? 'The current authenticated ' . $currentRole . ' session was accepted by settle_bill.php.'
                : 'The current authenticated ' . $currentRole . ' session was not accepted by settle_bill.php.';

            $idempotencyStatus = $idempotencyPassed ? 'PASS' : 'FAIL';
            $idempotencyMessage = $idempotencyPassed
                ? 'Two identical endpoint requests returned the existing disposable payment ID; exactly one fixture row existed. No order/session was changed.'
                : 'Replay verification failed. The temporary payment fixture is removed automatically; inspect endpoint authentication/response and database constraints.';
        } catch (Throwable $error) {
            error_log('Phase 1 idempotency verification failed: ' . $error->getMessage());
            $idempotencyStatus = 'FAIL';
            $idempotencyMessage = 'The disposable replay test could not complete; the temporary payment fixture is removed automatically.';
        } finally {
            if ($testPaymentKey !== null) {
                try {
                    $cleanup = $conn->prepare('DELETE FROM payments WHERE idempotency_key = ?');
                    $cleanup->bind_param('s', $testPaymentKey);
                    $cleanup->execute();
                    $cleanup->close();
                    $testPaymentKey = null;
                } catch (Throwable $error) {
                    error_log('Phase 1 test cleanup failed: ' . $error->getMessage());
                    $idempotencyStatus = 'FAIL';
                    $idempotencyMessage .= ' Cleanup failed; manually remove the row with idempotency_key ' . $testPaymentKey . '.';
                }
            }
        }
    }
    phase1TestAdd(
        $results,
        'Live admin/cashier session accepted',
        $liveRoleStatus,
        $liveRoleMessage
    );
    phase1TestAdd(
        $results,
        'Idempotency replay returns same payment with no duplicate',
        $idempotencyStatus,
        $idempotencyMessage
    );

    $overallStatus = 'PASS';
    foreach ($results as $result) {
        if ($result['status'] === 'FAIL') {
            $overallStatus = 'FAIL';
            break;
        }
        if ($result['status'] === 'SKIP' && $overallStatus === 'PASS') {
            $overallStatus = 'PARTIAL';
        }
    }

    echo json_encode([
        'access_url' => 'https://startupsgo.tech/saas_api/test_phase1.php',
        'status' => $overallStatus,
        'settle_endpoint_tested' => $endpointUrl,
        'results' => $results
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
} catch (Throwable $error) {
    error_log('Phase 1 verification script failed: ' . $error->getMessage());
    phase1TestJson('FAIL', 'The verification script encountered an unexpected error. Check the PHP error log.');
}
?>
