<?php
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
require_once __DIR__ . '/email_notification_common.php';

// Restrict this temporary public diagnostic to the owner's email address.
$allowedRecipient = 'yurajpatwa114@gmail.com';

function h($value) {
    return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
}

function report($label, $passed, $detail) {
    return [
        'label' => $label,
        'passed' => $passed,
        'detail' => $detail
    ];
}

$results = [];
$email = '';
$tenantId = 'startups_main';
$testResult = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = strtolower(trim((string)($_POST['email'] ?? '')));
    $validEmail = filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
    $isAllowedRecipient = $validEmail
        && hash_equals(strtolower($allowedRecipient), $email);
    if (!$isAllowedRecipient) {
        http_response_code(403);
        $results[] = report('Diagnostic access', false, 'This temporary test page only accepts the owner email configured in the PHP file.');
    } else {
        $results[] = report('Diagnostic access', true, 'Email matches the owner-only recipient allowlist.');

        $validTenant = preg_match('/^[A-Za-z0-9_-]{1,50}$/', $tenantId) === 1;
        $results[] = report('Recipient email', true, 'Valid owner email.');
        $results[] = report('Tenant ID', $validTenant, $validTenant ? 'Valid tenant ID format.' : 'Tenant ID must use letters, numbers, underscores, or hyphens.');

        $resendConfig = resendEmailConfig();
        $apiKey = $resendConfig['api_key'];
        $from = $resendConfig['from'];
        $results[] = report('Resend API key', $apiKey !== '', $apiKey !== '' ? 'Configured for PHP.' : 'No Resend API key is available to PHP.');
        $results[] = report('Resend sender', $from !== '', $from !== '' ? 'Configured for PHP.' : 'No sender address is available to PHP.');
        $results[] = report('PHP cURL', function_exists('curl_init'), function_exists('curl_init') ? 'Enabled.' : 'PHP cURL extension is unavailable.');

        $dbConfig = __DIR__ . '/db_config.php';
        if (!is_file($dbConfig)) {
            $results[] = report('Database config file', false, 'db_config.php was not found beside this diagnostic file.');
        } else {
            try {
                require_once $dbConfig;
                if (!isset($conn) || !($conn instanceof mysqli) || $conn->connect_errno) {
                    $results[] = report('Database connection', false, 'Could not connect using db_config.php.');
                } else {
                    $results[] = report('Database connection', true, 'Connected.');

                    $requiredTables = [
                        'customers',
                        'customer_notification_email_preferences',
                        'notification_email_queue',
                        'notifications'
                    ];
                    foreach ($requiredTables as $table) {
                        $tableStmt = $conn->prepare('SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ? LIMIT 1');
                        if (!$tableStmt) {
                            $results[] = report('Table: ' . $table, false, 'Could not check table.');
                            continue;
                        }
                        $tableStmt->bind_param('s', $table);
                        $tableStmt->execute();
                        $exists = $tableStmt->get_result()->num_rows > 0;
                        $tableStmt->close();
                        $results[] = report('Table: ' . $table, $exists, $exists ? 'Found.' : 'Missing; apply email_notifications_setup.sql or deploy the required notification schema.');
                    }

                    if ($validEmail && $validTenant) {
                        $customerStmt = $conn->prepare('SELECT 1 FROM customers WHERE LOWER(TRIM(email)) = ? AND tenant_id = ? LIMIT 1');
                        if ($customerStmt) {
                            $customerStmt->bind_param('ss', $email, $tenantId);
                            $customerStmt->execute();
                            $customerExists = $customerStmt->get_result()->num_rows > 0;
                            $customerStmt->close();
                            $results[] = report('Customer record', $customerExists, $customerExists ? 'Email exists for this tenant.' : 'No matching customer email + tenant ID. Check the tenant_id and synced account.');
                        }

                        if (in_array('customer_notification_email_preferences', $requiredTables, true)) {
                            $prefStmt = $conn->prepare('SELECT email_enabled, email_follow, email_wave, email_message FROM customer_notification_email_preferences WHERE tenant_id = ? AND LOWER(email) = ? LIMIT 1');
                            if ($prefStmt) {
                                $prefStmt->bind_param('ss', $tenantId, $email);
                                $prefStmt->execute();
                                $preferences = $prefStmt->get_result()->fetch_assoc();
                                $prefStmt->close();
                                if ($preferences) {
                                    $summary = 'Email alerts ' . ((int)$preferences['email_enabled'] === 1 ? 'ON' : 'OFF')
                                        . '; follows ' . ((int)$preferences['email_follow'] === 1 ? 'ON' : 'OFF')
                                        . ', waves ' . ((int)$preferences['email_wave'] === 1 ? 'ON' : 'OFF')
                                        . ', messages ' . ((int)$preferences['email_message'] === 1 ? 'ON' : 'OFF') . '.';
                                    $results[] = report('Email preferences', true, $summary);
                                } else {
                                    $results[] = report('Email preferences', false, 'No saved email preferences for this email and tenant. Sign in with email + PIN and enable email alerts in Settings.');
                                }
                            }
                        }

                        if (in_array('notification_email_queue', $requiredTables, true)) {
                            $queueStmt = $conn->prepare("SELECT status, COUNT(*) AS total FROM notification_email_queue WHERE tenant_id = ? AND LOWER(user_id) = ? GROUP BY status");
                            if ($queueStmt) {
                                $queueStmt->bind_param('ss', $tenantId, $email);
                                $queueStmt->execute();
                                $queueResult = $queueStmt->get_result();
                                $queueCounts = [];
                                while ($row = $queueResult->fetch_assoc()) {
                                    $queueCounts[$row['status']] = (int)$row['total'];
                                }
                                $queueStmt->close();
                                $summary = $queueCounts
                                    ? implode(', ', array_map(function ($status, $count) {
                                        return $status . ': ' . $count;
                                    }, array_keys($queueCounts), array_values($queueCounts)))
                                    : 'No queued notification events for this email and tenant yet.';
                                $results[] = report('Notification email queue', true, $summary);
                            }

                            $eligibleStmt = $conn->prepare("SELECT COUNT(*) AS total
                                FROM notification_email_queue q
                                INNER JOIN notifications n ON n.id = q.notification_id AND n.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci
                                LEFT JOIN customer_notification_email_preferences p
                                    ON p.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci AND p.email COLLATE utf8mb4_general_ci = q.user_id COLLATE utf8mb4_general_ci
                                INNER JOIN customers c
                                    ON c.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci AND LOWER(c.email) COLLATE utf8mb4_general_ci = LOWER(q.user_id) COLLATE utf8mb4_general_ci
                                WHERE q.tenant_id COLLATE utf8mb4_general_ci = ? AND LOWER(q.user_id) COLLATE utf8mb4_general_ci = ?
                                    AND q.status = 'pending'
                                    AND q.available_at <= CURRENT_TIMESTAMP
                                    AND (q.event_type != 'message' OR (
                                        q.created_at <= DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 MINUTE)
                                        AND NOT EXISTS (
                                            SELECT 1 FROM chat_messages cm
                                            WHERE cm.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci
                                                AND LOWER(cm.sender_id) COLLATE utf8mb4_general_ci = LOWER(q.user_id) COLLATE utf8mb4_general_ci
                                                AND LOWER(cm.receiver_id) COLLATE utf8mb4_general_ci = LOWER(n.sender_id) COLLATE utf8mb4_general_ci
                                                AND cm.created_at BETWEEN n.created_at
                                                    AND DATE_ADD(n.created_at, INTERVAL 1 MINUTE)
                                        )
                                    ))
                                    AND (p.email_enabled IS NULL OR p.email_enabled = 1)
                                    AND (p.email_follow IS NULL OR p.email_follow = 1 OR q.event_type NOT IN ('follow', 'follow_back'))
                                    AND (p.email_wave IS NULL OR p.email_wave = 1 OR q.event_type != 'wave')
                                    AND (p.email_message IS NULL OR p.email_message = 1 OR q.event_type != 'message')");
                            if ($eligibleStmt) {
                                $eligibleStmt->bind_param('ss', $tenantId, $email);
                                $eligibleStmt->execute();
                                $eligibleResult = $eligibleStmt->get_result();
                                $eligibleRow = $eligibleResult ? $eligibleResult->fetch_assoc() : null;
                                $eligibleCount = $eligibleRow ? (int)($eligibleRow['total'] ?? 0) : 0;
                                $eligibleStmt->close();
                                $detail = $eligibleCount > 0
                                    ? $eligibleCount . ' unread event(s) are ready for delivery or worker retry.'
                                    : 'No event currently meets all send conditions: pending, one minute old for messages, no reply within that minute, customer email matches, and email preferences enabled.';
                                $results[] = report('Worker-eligible events', $eligibleCount > 0, $detail);
                            }
                        }
                    }
                    $conn->close();
                }
            } catch (Throwable $exception) {
                error_log('Email delivery diagnostic database failure: ' . $exception->getMessage());
                $results[] = report('Database check', false, 'A database check failed: ' . $exception->getMessage());
            }
        }

        if ($validEmail) {
            if ($apiKey === '' || $from === '' || !function_exists('curl_init')) {
                $testResult = report('Resend test email', false, 'Cannot send: correct the recipient, Resend environment settings, or PHP cURL check above.');
            } else {
                $rateLimitPath = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'chiyabreak_email_test_' . hash('sha256', strtolower($allowedRecipient)) . '.lock';
                $rateLimitFile = @fopen($rateLimitPath, 'c+');
                if ($rateLimitFile === false || !flock($rateLimitFile, LOCK_EX)) {
                    if (is_resource($rateLimitFile)) fclose($rateLimitFile);
                    $testResult = report('Resend test email', false, 'Could not apply the required send-rate protection. Check PHP temp-directory permissions.');
                } else {
                    $lastSentAt = (int)trim((string)stream_get_contents($rateLimitFile));
                    if ($lastSentAt > 0 && time() - $lastSentAt < 900) {
                        $waitSeconds = 900 - (time() - $lastSentAt);
                        $testResult = report('Resend test email', false, 'A test was recently sent. Try again in about ' . (int)ceil($waitSeconds / 60) . ' minute(s).');
                    } else {
                        ftruncate($rateLimitFile, 0);
                        rewind($rateLimitFile);
                        fwrite($rateLimitFile, (string)time());
                        fflush($rateLimitFile);
                        $payload = json_encode([
                            'from' => $from,
                            'to' => [$allowedRecipient],
                            'subject' => 'ChiyaBreak email delivery test',
                            'text' => 'This is a test email from the ChiyaBreak notification diagnostic. If you received it, Resend delivery is working.',
                            'html' => '<p>This is a test email from the ChiyaBreak notification diagnostic.</p><p>If you received it, Resend delivery is working.</p>'
                        ]);

                        $curl = curl_init('https://api.resend.com/emails');
                        curl_setopt_array($curl, [
                            CURLOPT_RETURNTRANSFER => true,
                            CURLOPT_POST => true,
                            CURLOPT_POSTFIELDS => $payload,
                            CURLOPT_HTTPHEADER => [
                                'Authorization: Bearer ' . $apiKey,
                                'Content-Type: application/json'
                            ],
                            CURLOPT_TIMEOUT => 20
                        ]);
                        $response = curl_exec($curl);
                        $statusCode = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
                        $curlError = curl_error($curl);
                        curl_close($curl);

                        if ($response !== false && $statusCode >= 200 && $statusCode < 300) {
                            $testResult = report('Resend test email', true, 'Resend accepted the message (HTTP ' . $statusCode . '). Check the recipient inbox and spam folder.');
                        } else {
                            rewind($rateLimitFile);
                            ftruncate($rateLimitFile, 0);
                            fflush($rateLimitFile);
                            $responseData = json_decode((string)$response, true);
                            $providerMessage = is_array($responseData) ? (string)($responseData['message'] ?? $responseData['name'] ?? '') : '';
                            $detail = $curlError !== '' ? 'cURL error: ' . $curlError : 'Resend rejected the request (HTTP ' . $statusCode . ').';
                            if ($providerMessage !== '') {
                                $detail .= ' Provider: ' . substr($providerMessage, 0, 300);
                            }
                            $testResult = report('Resend test email', false, $detail);
                            error_log('Resend diagnostic request failed; HTTP ' . $statusCode . '; ' . substr($curlError ?: (string)$response, 0, 500));
                        }
                    }
                    flock($rateLimitFile, LOCK_UN);
                    fclose($rateLimitFile);
                }
            }
        }
    }
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>ChiyaBreak Email Delivery Test</title>
    <style>
        body { font: 16px/1.5 Arial, sans-serif; color: #172033; background: #f3f6fa; margin: 0; padding: 24px; }
        main { max-width: 720px; margin: 0 auto; background: #fff; border-radius: 16px; padding: 24px; box-shadow: 0 8px 32px #16243a14; }
        h1 { font-size: 22px; margin-top: 0; }
        label { display: block; margin: 14px 0 5px; font-weight: 600; }
        input { box-sizing: border-box; width: 100%; padding: 11px; border: 1px solid #ccd4df; border-radius: 8px; font-size: 16px; }
        button { margin: 16px 8px 0 0; padding: 11px 16px; border: 0; border-radius: 8px; background: #087f5b; color: white; font-weight: 700; cursor: pointer; }
        button.secondary { background: #334155; }
        .warning { padding: 12px; border-radius: 8px; background: #fff7e6; color: #704900; }
        .result { margin: 10px 0; padding: 12px; border-radius: 8px; background: #fff0f0; }
        .result.ok { background: #eaf8ef; }
        .result strong { display: block; }
        small { color: #526174; }
    </style>
</head>
<body>
<main>
    <h1>ChiyaBreak Email Delivery Test</h1>
    <p class="warning"><strong>Temporary diagnostic:</strong> this page is restricted to the owner email configured in the PHP file and sends at most one test every 15 minutes. Delete this PHP file from the server after testing. The Resend API key is never displayed.</p>
    <form method="post">
        <label for="email">Email to check / receive test message</label>
        <input id="email" name="email" type="email" required value="<?= h($email ?: $allowedRecipient) ?>">
        <button name="action" value="send_test">Check setup and send test email</button>
    </form>
    <?php if ($results || $testResult): ?>
        <h2>Results</h2>
        <?php foreach ($results as $result): ?>
            <div class="result <?= $result['passed'] ? 'ok' : '' ?>">
                <strong><?= $result['passed'] ? 'PASS' : 'CHECK' ?> — <?= h($result['label']) ?></strong>
                <?= h($result['detail']) ?>
            </div>
        <?php endforeach; ?>
        <?php if ($testResult): ?>
            <div class="result <?= $testResult['passed'] ? 'ok' : '' ?>">
                <strong><?= $testResult['passed'] ? 'PASS' : 'CHECK' ?> — <?= h($testResult['label']) ?></strong>
                <?= h($testResult['detail']) ?>
            </div>
        <?php endif; ?>
        <p><small>Tenant ID is fixed to startups_main in this PHP file. A successful Resend response confirms acceptance by Resend, not inbox placement. Also check spam and the Resend dashboard logs.</small></p>
    <?php endif; ?>
</main>
</body>
</html>
