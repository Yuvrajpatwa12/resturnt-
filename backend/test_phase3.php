
<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Content-Type: application/json; charset=UTF-8');
ini_set('display_errors', '0');
error_reporting(E_ALL);

function phase3AddResult(&$results, $name, $status, $message) {
    $results[] = [
        'test' => $name,
        'status' => $status,
        'message' => $message
    ];
}

function phase3EndpointUrl($file) {
    $https = !empty($_SERVER['HTTPS']) && strtolower((string)$_SERVER['HTTPS']) !== 'off';
    $scheme = $https ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'startupsgo.tech';
    $directory = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '/saas_api/test_phase3.php')), '/');
    return $scheme . '://' . $host . $directory . '/' . $file;
}

function phase3HttpRequest($url, $method = 'GET', $payload = null, $cookie = '') {
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

function phase3TableExists($conn, $tableName) {
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

function phase3Cleanup($conn, &$fixture) {
    if (!($conn instanceof mysqli) || empty($fixture)) {
        return true;
    }
    try {
        $tenantId = (string)($fixture['tenant_id'] ?? '');
        $sessionId = (int)($fixture['session_id'] ?? 0);
        $tableNumber = (int)($fixture['table_number'] ?? 0);
        $orderIds = array_values(array_unique(array_map('intval', $fixture['order_ids'] ?? [])));

        if ($tenantId !== '' && $tableNumber > 0) {
            $tableLookup = $conn->prepare(
                'SELECT id FROM restaurant_tables WHERE tenant_id = ? AND table_number = ? LIMIT 1'
            );
            $tableLookup->bind_param('si', $tenantId, $tableNumber);
            $tableLookup->execute();
            $tableRow = $tableLookup->get_result()->fetch_assoc();
            $tableLookup->close();
            if ($tableRow) {
                $tableId = (int)$tableRow['id'];
                $orders = $conn->prepare(
                    'SELECT id, session_id FROM orders WHERE tenant_id = ? AND table_id = ?'
                );
                $orders->bind_param('si', $tenantId, $tableId);
                $orders->execute();
                $rows = $orders->get_result();
                while ($row = $rows->fetch_assoc()) {
                    $orderIds[] = (int)$row['id'];
                    if ($sessionId <= 0) {
                        $sessionId = (int)($row['session_id'] ?? 0);
                    }
                }
                $orders->close();
            }
        }

        if ($tenantId !== '' && $sessionId > 0) {
            $orders = $conn->prepare('SELECT id FROM orders WHERE tenant_id = ? AND session_id = ?');
            $orders->bind_param('si', $tenantId, $sessionId);
            $orders->execute();
            $rows = $orders->get_result();
            while ($row = $rows->fetch_assoc()) {
                $orderIds[] = (int)$row['id'];
            }
            $orders->close();
            $orderIds = array_values(array_unique($orderIds));
        }

        if ($orderIds && phase3TableExists($conn, 'payment_orders')) {
            $paymentIds = [];
            $paymentLookup = $conn->prepare(
                'SELECT DISTINCT payment_id FROM payment_orders WHERE order_id = ?'
            );
            foreach ($orderIds as $orderId) {
                $paymentLookup->bind_param('i', $orderId);
                $paymentLookup->execute();
                $paymentRows = $paymentLookup->get_result();
                while ($row = $paymentRows->fetch_assoc()) {
                    $paymentIds[] = (int)$row['payment_id'];
                }
            }
            $paymentLookup->close();
            $paymentIds = array_values(array_unique($paymentIds));
            if ($paymentIds) {
                if (phase3TableExists($conn, 'payment_order_items')) {
                    $itemLinkDelete = $conn->prepare(
                        'DELETE FROM payment_order_items WHERE payment_id = ?'
                    );
                    foreach ($paymentIds as $paymentId) {
                        $itemLinkDelete->bind_param('i', $paymentId);
                        $itemLinkDelete->execute();
                    }
                    $itemLinkDelete->close();
                }
                $linkDelete = $conn->prepare('DELETE FROM payment_orders WHERE payment_id = ?');
                $paymentDelete = $conn->prepare('DELETE FROM payments WHERE id = ? AND tenant_id = ?');
                foreach ($paymentIds as $paymentId) {
                    $linkDelete->bind_param('i', $paymentId);
                    $linkDelete->execute();
                    $paymentDelete->bind_param('is', $paymentId, $tenantId);
                    $paymentDelete->execute();
                }
                $linkDelete->close();
                $paymentDelete->close();
            }
        }

        if ($sessionId > 0 && phase3TableExists($conn, 'payments')) {
            $paymentIds = [];
            $lookup = $conn->prepare('SELECT id FROM payments WHERE session_id = ? AND tenant_id = ?');
            $lookup->bind_param('is', $sessionId, $tenantId);
            $lookup->execute();
            $rows = $lookup->get_result();
            while ($row = $rows->fetch_assoc()) {
                $paymentIds[] = (int)$row['id'];
            }
            $lookup->close();
            if ($paymentIds && phase3TableExists($conn, 'payment_order_items')) {
                $itemLinkDelete = $conn->prepare(
                    'DELETE FROM payment_order_items WHERE payment_id = ?'
                );
                foreach ($paymentIds as $paymentId) {
                    $itemLinkDelete->bind_param('i', $paymentId);
                    $itemLinkDelete->execute();
                }
                $itemLinkDelete->close();
            }
            if ($paymentIds && phase3TableExists($conn, 'payment_orders')) {
                $linkDelete = $conn->prepare('DELETE FROM payment_orders WHERE payment_id = ?');
                foreach ($paymentIds as $paymentId) {
                    $linkDelete->bind_param('i', $paymentId);
                    $linkDelete->execute();
                }
                $linkDelete->close();
            }
            $paymentDelete = $conn->prepare('DELETE FROM payments WHERE session_id = ? AND tenant_id = ?');
            $paymentDelete->bind_param('is', $sessionId, $tenantId);
            $paymentDelete->execute();
            $paymentDelete->close();
        }

        if ($tenantId !== '' && $orderIds && phase3TableExists($conn, 'payment_orders')) {
            $orderLinkDelete = $conn->prepare('DELETE FROM payment_orders WHERE order_id = ?');
            foreach ($orderIds as $orderId) {
                $orderLinkDelete->bind_param('i', $orderId);
                $orderLinkDelete->execute();
            }
            $orderLinkDelete->close();
        }

        if ($tenantId !== '' && $orderIds && phase3TableExists($conn, 'notifications')) {
            $notificationIds = [];
            $notificationLookup = $conn->prepare(
                'SELECT id FROM notifications WHERE tenant_id = ? AND title = ?'
            );
            foreach ($orderIds as $orderId) {
                $title = 'New Order #' . $orderId;
                $notificationLookup->bind_param('ss', $tenantId, $title);
                $notificationLookup->execute();
                $rows = $notificationLookup->get_result();
                while ($row = $rows->fetch_assoc()) {
                    $notificationIds[] = (int)$row['id'];
                }
            }
            $notificationLookup->close();
            $notificationIds = array_values(array_unique($notificationIds));
            if ($notificationIds && phase3TableExists($conn, 'notification_email_queue')) {
                $queueDelete = $conn->prepare(
                    'DELETE FROM notification_email_queue WHERE notification_id = ?'
                );
                foreach ($notificationIds as $notificationId) {
                    $queueDelete->bind_param('i', $notificationId);
                    $queueDelete->execute();
                }
                $queueDelete->close();
            }
            if ($notificationIds) {
                $notificationDelete = $conn->prepare('DELETE FROM notifications WHERE id = ?');
                foreach ($notificationIds as $notificationId) {
                    $notificationDelete->bind_param('i', $notificationId);
                    $notificationDelete->execute();
                }
                $notificationDelete->close();
            }
        }

        if ($tenantId !== '' && $sessionId > 0) {
            if (phase3TableExists($conn, 'payment_order_items')) {
                $itemLinkDelete = $conn->prepare(
                    'DELETE poi FROM payment_order_items poi
                     INNER JOIN order_items oi ON oi.id = poi.order_item_id
                     INNER JOIN orders o ON o.id = oi.order_id
                     WHERE o.tenant_id = ? AND o.session_id = ?'
                );
                $itemLinkDelete->bind_param('si', $tenantId, $sessionId);
                $itemLinkDelete->execute();
                $itemLinkDelete->close();
            }
            $itemDelete = $conn->prepare(
                'DELETE oi FROM order_items oi
                 INNER JOIN orders o ON o.id = oi.order_id
                 WHERE o.tenant_id = ? AND o.session_id = ?'
            );
            $itemDelete->bind_param('si', $tenantId, $sessionId);
            $itemDelete->execute();
            $itemDelete->close();
            $orderDelete = $conn->prepare(
                'DELETE FROM orders WHERE tenant_id = ? AND session_id = ?'
            );
            $orderDelete->bind_param('si', $tenantId, $sessionId);
            $orderDelete->execute();
            $orderDelete->close();
            $sessionDelete = $conn->prepare(
                'DELETE FROM dining_sessions WHERE id = ? AND tenant_id = ?'
            );
            $sessionDelete->bind_param('is', $sessionId, $tenantId);
            $sessionDelete->execute();
            $sessionDelete->close();
        }
        if ($tenantId !== '' && $sessionId <= 0 && $orderIds) {
            if (phase3TableExists($conn, 'payment_order_items')) {
                $itemLinkDelete = $conn->prepare(
                    'DELETE poi FROM payment_order_items poi
                     INNER JOIN order_items oi ON oi.id = poi.order_item_id
                     WHERE oi.order_id = ?'
                );
                foreach ($orderIds as $orderId) {
                    $itemLinkDelete->bind_param('i', $orderId);
                    $itemLinkDelete->execute();
                }
                $itemLinkDelete->close();
            }
            $itemDelete = $conn->prepare(
                'DELETE oi FROM order_items oi
                 INNER JOIN orders o ON o.id = oi.order_id
                 WHERE o.tenant_id = ? AND o.id = ?'
            );
            $orderDelete = $conn->prepare(
                'DELETE FROM orders WHERE tenant_id = ? AND id = ?'
            );
            foreach ($orderIds as $orderId) {
                $itemDelete->bind_param('si', $tenantId, $orderId);
                $itemDelete->execute();
                $orderDelete->bind_param('si', $tenantId, $orderId);
                $orderDelete->execute();
            }
            $itemDelete->close();
            $orderDelete->close();
        }
        if ($tenantId !== '' && $tableNumber > 0) {
            $tableDelete = $conn->prepare(
                'DELETE FROM restaurant_tables WHERE tenant_id = ? AND table_number = ?'
            );
            $tableDelete->bind_param('si', $tenantId, $tableNumber);
            $tableDelete->execute();
            $tableDelete->close();
        }
        return true;
    } catch (Throwable $error) {
        error_log('Phase 3 verifier cleanup failed: ' . $error->getMessage());
        return false;
    }
}

$results = [];
$fixture = [];
$conn = null;
$phase3ResponseSent = false;
register_shutdown_function(function () use (&$conn, &$fixture, &$phase3ResponseSent) {
    phase3Cleanup($conn, $fixture);
    if ($phase3ResponseSent) {
        return;
    }
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
        error_log('Phase 3 verifier stopped unexpectedly: ' . $error['message']);
        if (!headers_sent()) {
            http_response_code(500);
            header('Content-Type: application/json; charset=UTF-8');
        }
        echo json_encode([
            'access_url' => phase3EndpointUrl('test_phase3.php'),
            'status' => 'FAIL',
            'message' => 'The verifier stopped because of a server-side PHP error. Check the PHP error log.'
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        $phase3ResponseSent = true;
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
    $baseUrl = rtrim(phase3EndpointUrl(''), '/');
    $authValid = false;
    if ($staffId > 0 && $tenantId !== '' && in_array($role, ['admin', 'cashier', 'waiter'], true)) {
        $authCheck = $conn->prepare('SELECT role, tenant_id FROM users WHERE id = ? LIMIT 1');
        $authCheck->bind_param('i', $staffId);
        $authCheck->execute();
        $user = $authCheck->get_result()->fetch_assoc();
        $authCheck->close();
        $authValid = $user &&
            strtolower(trim((string)$user['role'])) === $role &&
            (string)$user['tenant_id'] === $tenantId;
    }
    if (session_status() === PHP_SESSION_ACTIVE) {
        session_write_close();
    }

    phase3AddResult(
        $results,
        'Staff session and database connection',
        $authValid && $cookie !== '' ? 'PASS' : 'SKIP',
        $authValid && $cookie !== ''
            ? 'A valid logged-in staff session is available for disposable endpoint tests.'
            : 'Open this verifier in a logged-in Admin, Cashier, or Waiter browser session to run live tests.'
    );

    if (!$authValid || $cookie === '' || !function_exists('curl_init')) {
        $reason = !function_exists('curl_init')
            ? 'Live endpoint tests require PHP cURL.'
            : 'A valid staff browser session is required for live endpoint tests.';
        foreach ([
            'Server-side product price overrides a tampered client price',
            'Order submission replay does not create a duplicate',
            'Underpaid split is rejected without settling or recording payments',
            'Exact split settles and creates one payment row per method',
            'Settlement replay returns every split payment tender'
        ] as $test) {
            phase3AddResult($results, $test, 'SKIP', $reason);
        }
    } else {
        billingEnsureSchema($conn);
        $productColumns = [];
        $columnResult = $conn->query('SHOW COLUMNS FROM products');
        while ($column = $columnResult->fetch_assoc()) {
            $productColumns[strtolower($column['Field'])] = $column['Field'];
        }
        $titleColumn = $productColumns['title'] ?? $productColumns['name'] ?? null;
        $priceColumn = $productColumns['price'] ?? $productColumns['selling_price'] ?? null;
        $activeColumn = $productColumns['is_available'] ??
            $productColumns['is_active'] ??
            $productColumns['status'] ??
            null;
        if (!$titleColumn || !$priceColumn || !$activeColumn || !isset($productColumns['tenant_id'])) {
            throw new RuntimeException(
                'Products table must contain tenant_id, title/name, price/selling_price, and an availability column.'
            );
        }

        $activeCondition = strtolower($activeColumn) === 'status'
            ? "LOWER(`$activeColumn`) IN ('active', 'available', '1')"
            : "`$activeColumn` = 1";
        $variantsSelect = isset($productColumns['variants'])
            ? '`' . $productColumns['variants'] . '`'
            : 'NULL';
        $productStmt = $conn->prepare(
            "SELECT id, `$titleColumn` AS title, `$priceColumn` AS price,
                    `$activeColumn` AS active, $variantsSelect AS variants
             FROM products
             WHERE tenant_id = ? AND $activeCondition
             ORDER BY id LIMIT 1"
        );
        $productStmt->bind_param('s', $tenantId);
        $productStmt->execute();
        $product = $productStmt->get_result()->fetch_assoc();
        $productStmt->close();
        if (!$product) {
            throw new RuntimeException('No active product exists for this tenant to use as a safe test fixture.');
        }
        $variantName = '';
        $unitPrice = (float)$product['price'];
        $variants = json_decode((string)($product['variants'] ?? ''), true);
        if (is_array($variants)) {
            foreach ($variants as $variant) {
                if (is_array($variant) &&
                    isset($variant['name'], $variant['price']) &&
                    trim((string)$variant['name']) !== '' &&
                    is_numeric($variant['price'])) {
                    $variantName = trim((string)$variant['name']);
                    $unitPrice = (float)$variant['price'];
                    break;
                }
            }
        }
        $unitCents = (int)round($unitPrice * 100, 0, PHP_ROUND_HALF_UP);
        if ($unitCents <= 0) {
            throw new RuntimeException('The selected active product has no positive price for a safe test.');
        }

        $fixture['tenant_id'] = $tenantId;
        $fixture['order_ids'] = [];
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
        $fixture['table_number'] = $tableNumber;
        $idempotencyKey = 'phase3_' . bin2hex(random_bytes(16));
        $fakePrice = number_format(($unitCents / 100) + 99999.99, 2, '.', '');
        $placePayload = [
            'tenant_id' => $tenantId,
            'table_number' => $tableNumber,
            'user_id' => 'guest',
            'customer_email' => '',
            'idempotency_key' => $idempotencyKey,
            'total_amount' => $fakePrice,
            'items' => [[
                'product_id' => (int)$product['id'],
                'name' => (string)$product['title'],
                'quantity' => 1,
                'price' => $fakePrice,
                'price_at_order' => $fakePrice,
                'variant_name' => $variantName
            ]]
        ];
        $firstOrder = phase3HttpRequest(
            $baseUrl . '/place_order.php',
            'POST',
            $placePayload
        );
        $firstOrderId = (int)($firstOrder['json']['order_id'] ?? 0);
        if ($firstOrderId > 0) {
            $fixture['order_ids'][] = $firstOrderId;
            $sessionLookup = $conn->prepare(
                'SELECT session_id, total_amount FROM orders
                 WHERE id = ? AND tenant_id = ? LIMIT 1'
            );
            $sessionLookup->bind_param('is', $firstOrderId, $tenantId);
            $sessionLookup->execute();
            $storedOrder = $sessionLookup->get_result()->fetch_assoc();
            $sessionLookup->close();
            $fixture['session_id'] = (int)($storedOrder['session_id'] ?? 0);

            $itemLookup = $conn->prepare(
                'SELECT product_id, quantity, price_at_order
                 FROM order_items WHERE order_id = ? ORDER BY id'
            );
            $itemLookup->bind_param('i', $firstOrderId);
            $itemLookup->execute();
            $itemResult = $itemLookup->get_result();
            $storedItem = $itemResult->fetch_assoc();
            $itemCount = $itemResult->num_rows;
            $itemLookup->close();
            $pricePassed = $firstOrder['available'] &&
                $firstOrder['http_code'] === 200 &&
                ($firstOrder['json']['status'] ?? '') === 'success' &&
                $storedOrder &&
                (int)($storedItem['product_id'] ?? 0) === (int)$product['id'] &&
                (int)($storedItem['quantity'] ?? 0) === 1 &&
                (int)round((float)($storedItem['price_at_order'] ?? 0) * 100) === $unitCents &&
                (int)round((float)$storedOrder['total_amount'] * 100) === $unitCents &&
                (int)round((float)($firstOrder['json']['total_amount'] ?? 0) * 100) === $unitCents &&
                $itemCount === 1;
            phase3AddResult(
                $results,
                'Server-side product price overrides a tampered client price',
                $pricePassed ? 'PASS' : 'FAIL',
                $pricePassed
                    ? 'The endpoint ignored the fake client price and stored the tenant product price of ' .
                        number_format($unitCents / 100, 2, '.', '') . '.'
                    : 'The disposable order did not store the expected database product price and recomputed total.'
            );

            $secondOrder = phase3HttpRequest(
                $baseUrl . '/place_order.php',
                'POST',
                $placePayload
            );
            $countStmt = $conn->prepare(
                'SELECT COUNT(*) AS order_count FROM orders
                 WHERE tenant_id = ? AND idempotency_key = ?'
            );
            $countStmt->bind_param('ss', $tenantId, $idempotencyKey);
            $countStmt->execute();
            $orderCount = (int)$countStmt->get_result()->fetch_assoc()['order_count'];
            $countStmt->close();
            $idempotencyPassed = $secondOrder['available'] &&
                $secondOrder['http_code'] === 200 &&
                ($secondOrder['json']['status'] ?? '') === 'success' &&
                (int)($secondOrder['json']['order_id'] ?? 0) === $firstOrderId &&
                ($secondOrder['json']['idempotent_replay'] ?? false) === true &&
                $orderCount === 1;
            phase3AddResult(
                $results,
                'Order submission replay does not create a duplicate',
                $idempotencyPassed ? 'PASS' : 'FAIL',
                $idempotencyPassed
                    ? 'The repeated request returned the original order ID and exactly one row exists for its idempotency key.'
                    : 'The repeated request did not safely replay the original order. HTTP ' .
                        (string)($secondOrder['http_code'] ?? 'unavailable') . '; rows for key: ' . $orderCount . '.'
            );

            $servedFixture = $conn->prepare(
                "UPDATE order_items SET status = 'Completed' WHERE order_id = ?"
            );
            $servedFixture->bind_param('i', $firstOrderId);
            $servedFixture->execute();
            $servedFixture->close();
            $billResponse = phase3HttpRequest(
                $baseUrl . '/get_session_bill.php?session_id=' . (int)$fixture['session_id'],
                'GET',
                null,
                $cookie
            );
            $bill = is_array($billResponse['json'] ?? null) ? $billResponse['json'] : [];
            $totalCents = (int)round((float)($bill['grand_total'] ?? 0) * 100);
            $billLoaded = $billResponse['available'] &&
                $billResponse['http_code'] === 200 &&
                ($bill['status'] ?? '') === 'success' &&
                $totalCents > 0 &&
                count($bill['order_ids'] ?? []) === 1;

            if (!$billLoaded) {
                phase3AddResult(
                    $results,
                    'Underpaid split is rejected without settling or recording payments',
                    'FAIL',
                    'Could not load the disposable session bill before testing split-payment validation.'
                );
                phase3AddResult(
                    $results,
                    'Exact split settles and creates one payment row per method',
                    'SKIP',
                    'Skipped because the current server-calculated session bill was unavailable.'
                );
            } elseif (!in_array($role, ['admin', 'cashier'], true)) {
                foreach ([
                    'Underpaid split is rejected without settling or recording payments',
                    'Exact split settles and creates one payment row per method'
                ] as $test) {
                    phase3AddResult(
                        $results,
                        $test,
                        'SKIP',
                        'Sign in as an Admin or Cashier to run settlement tests; the current staff role is not permitted to settle.'
                    );
                }
            } else {
                $settlementKey = 'phase3_settle_' . bin2hex(random_bytes(16));
                $sessionId = (int)$fixture['session_id'];
                if ($totalCents <= 1) {
                    phase3AddResult(
                        $results,
                        'Underpaid split is rejected without settling or recording payments',
                        'SKIP',
                        'The bill is under two cents, so there is no positive lower payment amount to submit.'
                    );
                } else {
                $underFirstCents = (int)floor($totalCents / 2);
                $underSecondCents = $underFirstCents;
                if ($underFirstCents + $underSecondCents >= $totalCents) {
                    $underSecondCents = $totalCents - $underFirstCents - 1;
                }
                $underpaidParts = $underSecondCents > 0
                    ? [
                        ['method' => 'Cash', 'amount' => number_format($underFirstCents / 100, 2, '.', '')],
                        ['method' => 'Card', 'amount' => number_format($underSecondCents / 100, 2, '.', '')]
                    ]
                    : [
                        ['method' => 'Cash', 'amount' => number_format(($totalCents - 1) / 100, 2, '.', '')]
                    ];
                $underpaid = phase3HttpRequest(
                    $baseUrl . '/settle_bill.php',
                    'POST',
                    [
                        'tenant_id' => $tenantId,
                        'session_id' => $sessionId,
                        'idempotency_key' => $settlementKey,
                        'payments' => $underpaidParts
                    ],
                    $cookie
                );
                $statusStmt = $conn->prepare(
                    'SELECT status FROM dining_sessions WHERE id = ? AND tenant_id = ? LIMIT 1'
                );
                $statusStmt->bind_param('is', $sessionId, $tenantId);
                $statusStmt->execute();
                $status = $statusStmt->get_result()->fetch_assoc()['status'] ?? '';
                $statusStmt->close();
                $paymentsBeforeExact = $conn->prepare(
                    'SELECT COUNT(*) AS payment_count FROM payments
                     WHERE tenant_id = ? AND session_id = ? AND idempotency_key LIKE ?'
                );
                $likeKey = $settlementKey . '%';
                $paymentsBeforeExact->bind_param('sis', $tenantId, $sessionId, $likeKey);
                $paymentsBeforeExact->execute();
                $paymentCountBeforeExact = (int)$paymentsBeforeExact->get_result()->fetch_assoc()['payment_count'];
                $paymentsBeforeExact->close();
                $underpaidExpectedStatus = $underpaid['available'] &&
                    $underpaid['http_code'] === 409 &&
                    stripos((string)($underpaid['json']['message'] ?? ''), 'exactly equal') !== false;
                $underpaidPassed = $underpaidExpectedStatus &&
                    strtolower((string)$status) !== 'settled' &&
                    $paymentCountBeforeExact === 0;
                phase3AddResult(
                    $results,
                    'Underpaid split is rejected without settling or recording payments',
                    $underpaidPassed ? 'PASS' : 'FAIL',
                    $underpaidPassed
                        ? 'The endpoint rejected the mismatch with HTTP 409, left the session unsettled, and inserted no payment rows.'
                        : 'Expected a clear HTTP 409 mismatch with no state or ledger changes. Received HTTP ' .
                            (string)($underpaid['http_code'] ?? 'unavailable') . ': ' .
                            (string)($underpaid['json']['message'] ?? $underpaid['error'] ?? '') .
                            '; session=' . (string)$status . '; payments=' . $paymentCountBeforeExact . '.'
                );
                }

                $firstPartCents = (int)floor($totalCents / 2);
                if ($firstPartCents <= 0) {
                    $firstPartCents = 1;
                }
                $secondPartCents = $totalCents - $firstPartCents;
                $exactSettlementPayload = [
                    'tenant_id' => $tenantId,
                    'session_id' => $sessionId,
                    'idempotency_key' => $settlementKey,
                    'payments' => [
                        ['method' => 'Cash', 'amount' => number_format($firstPartCents / 100, 2, '.', '')],
                        ['method' => 'Card', 'amount' => number_format($secondPartCents / 100, 2, '.', '')]
                    ]
                ];
                $exactResponse = phase3HttpRequest(
                    $baseUrl . '/settle_bill.php',
                    'POST',
                    $exactSettlementPayload,
                    $cookie
                );
                $statusStmt = $conn->prepare(
                    'SELECT status FROM dining_sessions WHERE id = ? AND tenant_id = ? LIMIT 1'
                );
                $statusStmt->bind_param('is', $sessionId, $tenantId);
                $statusStmt->execute();
                $settledStatus = $statusStmt->get_result()->fetch_assoc()['status'] ?? '';
                $statusStmt->close();
                $paymentRowsStmt = $conn->prepare(
                    "SELECT id, amount, method FROM payments
                     WHERE tenant_id = ? AND session_id = ?
                       AND (idempotency_key = ? OR idempotency_key = CONCAT(?, '.1'))
                     ORDER BY id"
                );
                $paymentRowsStmt->bind_param(
                    'siss',
                    $tenantId,
                    $sessionId,
                    $settlementKey,
                    $settlementKey
                );
                $paymentRowsStmt->execute();
                $paymentRows = $paymentRowsStmt->get_result()->fetch_all(MYSQLI_ASSOC);
                $paymentRowsStmt->close();
                $ledgerCents = 0;
                $methods = [];
                foreach ($paymentRows as $paymentRow) {
                    $ledgerCents += (int)round((float)$paymentRow['amount'] * 100);
                    $methods[] = (string)$paymentRow['method'];
                }
                $exactPassed = $exactResponse['available'] &&
                    $exactResponse['http_code'] === 200 &&
                    ($exactResponse['json']['status'] ?? '') === 'success' &&
                    strtolower((string)$settledStatus) === 'settled' &&
                    count($paymentRows) === 2 &&
                    $ledgerCents === $totalCents &&
                    $methods === ['Cash', 'Card'];
                phase3AddResult(
                    $results,
                    'Exact split settles and creates one payment row per method',
                    $exactPassed ? 'PASS' : 'FAIL',
                    $exactPassed
                        ? 'The exact server total settled successfully and was recorded as separate Cash and Card ledger rows.'
                        : 'Exact split did not settle with two correctly valued ledger rows. HTTP ' .
                            (string)($exactResponse['http_code'] ?? 'unavailable') . '; session=' .
                            (string)$settledStatus . '; payment rows=' . count($paymentRows) . '.'
                );
                if ($exactPassed) {
                    $replayResponse = phase3HttpRequest(
                        $baseUrl . '/settle_bill.php',
                        'POST',
                        $exactSettlementPayload,
                        $cookie
                    );
                    $replayedPayments = $replayResponse['json']['payments'] ?? null;
                    $replayPassed = $replayResponse['available'] &&
                        $replayResponse['http_code'] === 200 &&
                        ($replayResponse['json']['status'] ?? '') === 'success' &&
                        ($replayResponse['json']['idempotent_replay'] ?? false) === true &&
                        is_array($replayedPayments) &&
                        count($replayedPayments) === 2 &&
                        (string)($replayResponse['json']['amount'] ?? '') ===
                            number_format($totalCents / 100, 2, '.', '') &&
                        (int)($replayedPayments[0]['payment_id'] ?? 0) ===
                            (int)$paymentRows[0]['id'] &&
                        (int)($replayedPayments[1]['payment_id'] ?? 0) ===
                            (int)$paymentRows[1]['id'] &&
                        ($replayedPayments[0]['method'] ?? '') === 'Cash' &&
                        ($replayedPayments[1]['method'] ?? '') === 'Card';
                    phase3AddResult(
                        $results,
                        'Settlement replay returns every split payment tender',
                        $replayPassed ? 'PASS' : 'FAIL',
                        $replayPassed
                            ? 'The replay returned both original tender rows, methods, IDs, and the combined amount.'
                            : 'Settlement replay did not return the full original split payment. HTTP ' .
                                (string)($replayResponse['http_code'] ?? 'unavailable') . '.'
                    );
                } else {
                    phase3AddResult(
                        $results,
                        'Settlement replay returns every split payment tender',
                        'SKIP',
                        'Skipped because the initial split settlement did not pass.'
                    );
                }
            }
        } else {
            phase3AddResult(
                $results,
                'Server-side product price overrides a tampered client price',
                'FAIL',
                'place_order.php did not return a valid disposable order. HTTP ' .
                    (string)($firstOrder['http_code'] ?? 'unavailable') . ': ' .
                    (string)($firstOrder['json']['message'] ?? $firstOrder['error'] ?? '')
            );
            phase3AddResult(
                $results,
                'Order submission replay does not create a duplicate',
                'SKIP',
                'Skipped because the first disposable order was not accepted.'
            );
            phase3AddResult(
                $results,
                'Underpaid split is rejected without settling or recording payments',
                'SKIP',
                'Skipped because no disposable order/session was created.'
            );
            phase3AddResult(
                $results,
                'Exact split settles and creates one payment row per method',
                'SKIP',
                'Skipped because no disposable order/session was created.'
            );
            phase3AddResult(
                $results,
                'Settlement replay returns every split payment tender',
                'SKIP',
                'Skipped because no disposable order/session was created.'
            );
        }
    }

    $cleanupPassed = phase3Cleanup($conn, $fixture);
    if ($cleanupPassed) {
        $fixture = [];
    }
    phase3AddResult(
        $results,
        'Disposable test data cleanup',
        $cleanupPassed ? 'PASS' : 'FAIL',
        $cleanupPassed
            ? 'The temporary session, table, order, items, payment rows, and related notifications were removed.'
            : 'Cleanup did not complete; inspect the PHP error log before removing only this verifier fixture.'
    );
} catch (Throwable $error) {
    error_log('Phase 3 verifier failed: ' . $error->getMessage());
    phase3AddResult(
        $results,
        'Verifier setup',
        'FAIL',
        'Could not complete the verifier setup. Check the server PHP error log for details.'
    );
    $cleanupPassed = phase3Cleanup($conn, $fixture);
    if ($cleanupPassed) {
        $fixture = [];
    }
    phase3AddResult(
        $results,
        'Disposable test data cleanup',
        $cleanupPassed ? 'PASS' : 'FAIL',
        $cleanupPassed
            ? 'Any temporary rows created before the failure were removed.'
            : 'Cleanup did not complete; inspect the PHP error log.'
    );
}

$statuses = array_column($results, 'status');
$overall = in_array('FAIL', $statuses, true)
    ? 'FAIL'
    : (in_array('SKIP', $statuses, true) ? 'PARTIAL' : 'PASS');
echo json_encode([
    'access_url' => phase3EndpointUrl('test_phase3.php'),
    'status' => $overall,
    'message' => 'Phase 3 tests use a unique temporary table/order and attempt cleanup before returning the report.',
    'results' => $results
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
$phase3ResponseSent = true;
?>
