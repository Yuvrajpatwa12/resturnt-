<?php
/**
 * Read-only deployment check for the subscription API and Flutter web sites.
 * Remove this file from the public server after testing.
 */

header('Content-Type: text/html; charset=UTF-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('X-Content-Type-Options: nosniff');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
    http_response_code(405);
    header('Allow: GET');
    exit('Use GET to run this read-only check.');
}

ini_set('display_errors', '0');

function h($value)
{
    return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function addCheck(&$checks, $group, $name, $passed, $message)
{
    $checks[] = [
        'group' => $group,
        'name' => $name,
        'passed' => (bool)$passed,
        'message' => $message,
    ];
}

function fetchUrl($url)
{
    if (!extension_loaded('curl')) {
        return ['ok' => false, 'status' => 0, 'body' => ''];
    }

    $handle = curl_init($url);
    curl_setopt_array($handle, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_MAXREDIRS => 3,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT => 12,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_PROTOCOLS => CURLPROTO_HTTPS,
        CURLOPT_REDIR_PROTOCOLS => CURLPROTO_HTTPS,
        CURLOPT_USERAGENT => 'ChiyaBreak-ReadOnly-HealthCheck/1.0',
    ]);

    $body = curl_exec($handle);
    $status = (int)curl_getinfo($handle, CURLINFO_HTTP_CODE);
    $ok = $body !== false && $status >= 200 && $status < 400;
    curl_close($handle);

    return [
        'ok' => $ok,
        'status' => $status,
        'body' => is_string($body) ? $body : '',
    ];
}

$checks = [];
$configPath = __DIR__ . '/db_config.php';
$conn = null;

addCheck(
    $checks,
    'PHP Server',
    'PHP runtime',
    version_compare(PHP_VERSION, '7.4.0', '>='),
    'PHP ' . PHP_VERSION
);
addCheck(
    $checks,
    'PHP Server',
    'MySQLi extension',
    extension_loaded('mysqli'),
    extension_loaded('mysqli') ? 'Installed' : 'Missing'
);
addCheck(
    $checks,
    'PHP Server',
    'cURL extension',
    extension_loaded('curl'),
    extension_loaded('curl') ? 'Installed' : 'Missing; remote site checks cannot run'
);

if (!is_file($configPath)) {
    addCheck($checks, 'Database', 'Database configuration', false, 'db_config.php not found beside this test file.');
} else {
    $previousHandler = set_error_handler(function () {
        throw new ErrorException('Database initialization failed.');
    });
    ob_start();
    try {
        require_once $configPath;
    } catch (Throwable $e) {
        $conn = null;
    } finally {
        ob_end_clean();
        restore_error_handler();
    }

    $databaseReady = isset($conn) && $conn instanceof mysqli && !$conn->connect_error;
    addCheck(
        $checks,
        'Database',
        'MySQL connection',
        $databaseReady,
        $databaseReady ? 'Connected' : 'Could not connect; check Hostinger database configuration'
    );

    if ($databaseReady) {
        foreach (['tenants', 'subscription_packages', 'subscription_requests'] as $table) {
            $stmt = $conn->prepare(
                'SELECT COUNT(*) AS table_count
                 FROM information_schema.tables
                 WHERE table_schema = DATABASE() AND table_name = ?'
            );
            $stmt->bind_param('s', $table);
            $stmt->execute();
            $result = $stmt->get_result();
            $row = $result ? $result->fetch_assoc() : null;
            $exists = $row && (int)$row['table_count'] > 0;
            addCheck(
                $checks,
                'Database',
                $table . ' table',
                $exists,
                $exists ? 'Ready' : 'Missing; open the subscription page once or apply subscription_setup.sql'
            );
            $stmt->close();
        }

        try {
            $result = $conn->query('SELECT id FROM subscription_packages LIMIT 1');
            addCheck($checks, 'Database', 'Package read access', $result !== false, $result !== false ? 'Read-only query succeeded' : 'Could not read subscription packages');
        } catch (Throwable $e) {
            addCheck($checks, 'Database', 'Package read access', false, 'Subscription package table is unavailable');
        }

        $requiredColumns = [
            'subscription_requests' => ['id', 'tenant_id', 'package_id', 'status', 'requested_at'],
            'subscription_packages' => ['id', 'name', 'duration_days', 'price'],
            'tenants' => ['tenant_id', 'restaurant_name', 'custom_domain', 'plan', 'subscription_end'],
        ];
        $missingColumns = [];
        foreach ($requiredColumns as $table => $columns) {
            foreach ($columns as $column) {
                $stmt = $conn->prepare(
                    'SELECT COUNT(*) AS column_count
                     FROM information_schema.columns
                     WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?'
                );
                $stmt->bind_param('ss', $table, $column);
                $stmt->execute();
                $result = $stmt->get_result();
                $row = $result ? $result->fetch_assoc() : null;
                if (!$row || (int)$row['column_count'] === 0) {
                    $missingColumns[] = "$table.$column";
                }
                $stmt->close();
            }
        }

        if ($missingColumns) {
            addCheck(
                $checks,
                'Subscription API',
                'Pending-request database query',
                false,
                'Missing required database columns: ' . implode(', ', $missingColumns)
            );
        } else {
            try {
                $result = $conn->query("
                    SELECT r.id, r.tenant_id, r.package_id, r.status, r.requested_at,
                           p.name AS package_name, p.duration_days, p.price,
                           t.restaurant_name, t.custom_domain,
                           t.plan AS current_plan, t.subscription_end
                    FROM subscription_requests r
                    JOIN subscription_packages p ON p.id = r.package_id
                    LEFT JOIN tenants t
                      ON t.tenant_id COLLATE utf8mb4_unicode_ci = r.tenant_id COLLATE utf8mb4_unicode_ci
                      OR t.custom_domain COLLATE utf8mb4_unicode_ci = r.tenant_id COLLATE utf8mb4_unicode_ci
                    WHERE r.status = 'Pending'
                    ORDER BY r.requested_at ASC
                    LIMIT 0
                ");
                if ($result === false) {
                    throw new RuntimeException('Pending request query failed.');
                }
                $result->free();

                $countResult = $conn->query(
                    "SELECT COUNT(*) AS pending_count FROM subscription_requests WHERE status = 'Pending'"
                );
                $countRow = $countResult ? $countResult->fetch_assoc() : null;
                $pendingCount = (int)($countRow['pending_count'] ?? 0);
                addCheck(
                    $checks,
                    'Subscription API',
                    'Pending-request database query',
                    true,
                    "Super Admin query is valid; $pendingCount pending request(s) found"
                );
            } catch (Throwable $e) {
                addCheck(
                    $checks,
                    'Subscription API',
                    'Pending-request database query',
                    false,
                    'Database rejected the Super Admin query: ' . $e->getMessage()
                );
            }
        }
    }
}

$apiUrl = 'https://startupsgo.tech/saas_api/subscription_api.php?action=get_packages';
$api = fetchUrl($apiUrl);
$apiJson = $api['ok'] ? json_decode($api['body'], true) : null;
$apiReady = is_array($apiJson)
    && ($apiJson['status'] ?? '') === 'success'
    && isset($apiJson['data'])
    && is_array($apiJson['data']);
addCheck(
    $checks,
    'Subscription API',
    'GET subscription packages',
    $apiReady,
    $apiReady ? 'API returned a valid package list' : ($api['status'] ? 'API returned an invalid response' : 'API could not be reached (HTTP ' . $api['status'] . ')')
);

foreach ([
    'Super Admin web app' => 'https://startupsgo.tech/superadmin',
    'Restaurant web app' => 'https://chiyalaya.store/admin',
] as $name => $url) {
    $site = fetchUrl($url);
    $isFlutter = $site['ok'] && (
        strpos($site['body'], 'flutter_bootstrap.js') !== false
        || strpos($site['body'], 'main.dart.js') !== false
    );
    addCheck(
        $checks,
        'Flutter Web',
        $name,
        $isFlutter,
        $isFlutter
            ? 'Site is reachable and served Flutter Web HTML'
            : ($site['status'] ? 'Site responded, but Flutter Web entry file was not detected' : 'Site could not be reached (HTTP ' . $site['status'] . ')')
    );
}

$passedCount = 0;
foreach ($checks as $check) {
    if ($check['passed']) {
        $passedCount++;
    }
}
$allPassed = $passedCount === count($checks);
$groups = [];
foreach ($checks as $check) {
    $groups[$check['group']][] = $check;
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>ChiyaBreak Deployment Check</title>
    <style>
        body { margin: 0; padding: 24px; background: #f1f5f9; color: #0f172a; font: 15px/1.5 system-ui, sans-serif; }
        main { max-width: 900px; margin: auto; }
        header, section { margin-bottom: 18px; padding: 20px; border: 1px solid #dbe3ee; border-radius: 14px; background: #fff; }
        h1 { margin: 0 0 6px; font-size: 23px; }
        h2 { margin: 0 0 12px; font-size: 17px; }
        p { margin: 5px 0; color: #475569; }
        .summary { font-weight: 700; color: <?= $allPassed ? '#15803d' : '#b91c1c' ?>; }
        .row { display: grid; grid-template-columns: minmax(180px, 1fr) 70px 2fr; gap: 12px; padding: 10px 0; border-top: 1px solid #e2e8f0; }
        .pass { color: #15803d; font-weight: 700; }
        .fail { color: #b91c1c; font-weight: 700; }
        footer { color: #64748b; font-size: 13px; }
        @media (max-width: 600px) { body { padding: 12px; } .row { grid-template-columns: 1fr auto; } .message { grid-column: 1 / -1; } }
    </style>
</head>
<body>
<main>
    <header>
        <h1>ChiyaBreak Deployment Check</h1>
        <p class="summary"><?= $passedCount ?> / <?= count($checks) ?> checks passed<?= $allPassed ? ' — all checked services look ready.' : ' — review failed checks below.' ?></p>
        <p>This page only runs read-only checks; it does not create, approve, or delete subscription requests.</p>
    </header>
    <?php foreach ($groups as $group => $items): ?>
        <section>
            <h2><?= h($group) ?></h2>
            <?php foreach ($items as $item): ?>
                <div class="row">
                    <strong><?= h($item['name']) ?></strong>
                    <span class="<?= $item['passed'] ? 'pass' : 'fail' ?>"><?= $item['passed'] ? 'PASS' : 'FAIL' ?></span>
                    <span class="message"><?= h($item['message']) ?></span>
                </div>
            <?php endforeach; ?>
        </section>
    <?php endforeach; ?>
    <footer>For security, delete <strong>subscription_health_check.php</strong> from the public server after testing. This check does not submit a real owner request or verify Super Admin login; test those in the app.</footer>
</main>
</body>
</html>
