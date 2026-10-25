<?php
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

$allowedRecipient = 'yurajpatwa114@gmail.com';

function h($value) {
    return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
}

$tenantId = 'startups_main';
$message = '';
$actionResult = null;

$dbConfig = __DIR__ . '/db_config.php';
if (!is_file($dbConfig)) {
    die("Error: db_config.php not found beside this file.");
}
require_once $dbConfig;
require_once __DIR__ . '/email_notification_common.php';

$resendConfig = resendEmailConfig();
$apiKey = $resendConfig['api_key'];
$from = $resendConfig['from'];

// Handle Simulation Actions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $act = $_POST['action'] ?? '';
    if ($act === 'test_follow') {
        try {
            $notif_title = "Test Follower Alert!";
            $notif_msg = "@debug_user just followed your profile.";
            $notif_ins = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type, sender_id) VALUES (?, ?, ?, ?, 'follow', 'debug_user')");
            $notif_ins->bind_param("ssss", $tenantId, $allowedRecipient, $notif_title, $notif_msg);
            if ($notif_ins->execute()) {
                $notification_id = (int)$conn->insert_id;
                queueEmailNotification($conn, $tenantId, $allowedRecipient, $notification_id, 'follow');
                $message = "Simulated follow event inserted! Notification ID: $notification_id and queued in notification_email_queue.";
            } else {
                $message = "Error inserting notification: " . $conn->error;
            }
            $notif_ins->close();
        } catch (Throwable $e) {
            $message = "Exception during follow test: " . $e->getMessage();
        }
    } elseif ($act === 'test_message') {
        try {
            $notif_title = "💬 Test Message from @debug_user";
            $notif_msg = "Hello! This is a diagnostic test message.";
            $notif_ins = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type, sender_id) VALUES (?, ?, ?, ?, 'message', 'debug_user')");
            $notif_ins->bind_param("ssss", $tenantId, $allowedRecipient, $notif_title, $notif_msg);
            if ($notif_ins->execute()) {
                $notification_id = (int)$conn->insert_id;
                queueEmailNotification($conn, $tenantId, $allowedRecipient, $notification_id, 'message');
                $message = "Simulated message event inserted! Notification ID: $notification_id and queued in notification_email_queue.";
            } else {
                $message = "Error inserting notification: " . $conn->error;
            }
            $notif_ins->close();
        } catch (Throwable $e) {
            $message = "Exception during message test: " . $e->getMessage();
        }
    } elseif ($act === 'run_worker_now') {
        // Execute the worker eligibility checks directly for testing.
        try {
            if ($apiKey === '') {
                $message = "Worker Error: Resend API key is missing. Configure the private resend_config.php file or RESEND_API_KEY environment variable.";
            } else {
                $sql = "SELECT q.id AS queue_id, q.tenant_id, q.user_id, q.notification_id,
                        q.event_type, n.title, n.message, n.is_read, c.email AS recipient
                    FROM notification_email_queue q
                    INNER JOIN notifications n ON n.id = q.notification_id AND n.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci
                    LEFT JOIN customer_notification_email_preferences p
                        ON p.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci AND p.email COLLATE utf8mb4_general_ci = q.user_id COLLATE utf8mb4_general_ci
                    INNER JOIN customers c ON c.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci AND LOWER(c.email) COLLATE utf8mb4_general_ci = LOWER(q.user_id) COLLATE utf8mb4_general_ci
                    WHERE q.status IN ('pending', 'processing') AND q.tenant_id = ? AND LOWER(q.user_id) = ?
                        AND (p.email_enabled IS NULL OR p.email_enabled = 1)
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
                    ORDER BY q.id DESC LIMIT 10";
                $stmt = $conn->prepare($sql);
                $stmt->bind_param("ss", $tenantId, $allowedRecipient);
                $stmt->execute();
                $res = $stmt->get_result();
                $pendingItems = $res->fetch_all(MYSQLI_ASSOC);
                $stmt->close();

                if (!$pendingItems) {
                    $message = "No pending queued notifications found for $allowedRecipient to send.";
                } else {
                    $sentCount = 0;
                    $workerErrors = [];
                    foreach ($pendingItems as $item) {
                        $qId = (int)$item['queue_id'];
                        $title = trim((string)$item['title']);
                        $detail = $item['event_type'] === 'message' ? 'You have a new chat message.' : trim((string)$item['message']);
                        $payload = json_encode([
                            'from' => $from,
                            'to' => [$item['recipient']],
                            'subject' => 'ChiyaBreak Live Alert: ' . $title,
                            'text' => $title . "\n" . $detail,
                            'html' => '<p><strong>' . h($title) . '</strong></p><p>' . h($detail) . '</p>'
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
                        $curlErr = curl_error($curl);
                        curl_close($curl);

                        if ($response !== false && $statusCode >= 200 && $statusCode < 300) {
                            $conn->query("UPDATE notification_email_queue SET status = 'sent', sent_at = CURRENT_TIMESTAMP WHERE id = $qId");
                            $sentCount++;
                        } else {
                            $errDetail = "HTTP $statusCode " . ($curlErr ?: $response);
                            $workerErrors[] = "Queue #$qId failed: " . substr($errDetail, 0, 200);
                            $conn->query("UPDATE notification_email_queue SET attempts = attempts + 1, last_error = '" . $conn->real_escape_string($errDetail) . "' WHERE id = $qId");
                        }
                    }
                    $message = "Worker Execution Complete. Successfully sent $sentCount email(s)." . ($workerErrors ? " Errors: " . implode(' | ', $workerErrors) : '');
                }
            }
        } catch (Throwable $e) {
            $message = "Worker Execution Exception: " . $e->getMessage();
        }
    }
}

// Query Current System State
$recentNotifications = [];
$notifStmt = $conn->prepare("SELECT id, user_id, title, message, type, is_read, created_at FROM notifications WHERE tenant_id = ? AND LOWER(user_id) = ? ORDER BY id DESC LIMIT 10");
if ($notifStmt) {
    $notifStmt->bind_param("ss", $tenantId, $allowedRecipient);
    $notifStmt->execute();
    $recentNotifications = $notifStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $notifStmt->close();
}

$recentQueue = [];
$queueStmt = $conn->prepare("SELECT id, notification_id, event_type, status, available_at, created_at, attempts, last_error FROM notification_email_queue WHERE tenant_id = ? AND LOWER(user_id) = ? ORDER BY id DESC LIMIT 10");
if ($queueStmt) {
    $queueStmt->bind_param("ss", $tenantId, $allowedRecipient);
    $queueStmt->execute();
    $recentQueue = $queueStmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $queueStmt->close();
}

$userPref = null;
$prefStmt = $conn->prepare("SELECT email_enabled, email_follow, email_wave, email_message, updated_at FROM customer_notification_email_preferences WHERE tenant_id = ? AND LOWER(email) = ? LIMIT 1");
if ($prefStmt) {
    $prefStmt->bind_param("ss", $tenantId, $allowedRecipient);
    $prefStmt->execute();
    $userPref = $prefStmt->get_result()->fetch_assoc();
    $prefStmt->close();
}

$conn->close();
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>ChiyaBreak Notification Live Debugger</title>
    <style>
        body { font: 15px/1.5 Arial, sans-serif; color: #172033; background: #f0f4f8; margin: 0; padding: 24px; }
        main { max-width: 800px; margin: 0 auto; background: #fff; border-radius: 12px; padding: 24px; box-shadow: 0 4px 20px #00000012; }
        h1 { font-size: 20px; margin-top: 0; color: #0f172a; }
        h2 { font-size: 16px; margin-top: 24px; border-bottom: 2px solid #e2e8f0; padding-bottom: 6px; }
        .msg { padding: 12px; border-radius: 8px; background: #e0f2fe; color: #0369a1; font-weight: bold; margin-bottom: 16px; }
        .btn-group { margin: 16px 0; }
        button { padding: 10px 16px; border: 0; border-radius: 6px; font-weight: bold; cursor: pointer; margin-right: 8px; margin-bottom: 8px; }
        button.primary { background: #2563eb; color: white; }
        button.secondary { background: #059669; color: white; }
        button.danger { background: #dc2626; color: white; }
        table { width: 100%; border-collapse: collapse; margin-top: 8px; font-size: 13px; }
        th, td { border: 1px solid #cbd5e1; padding: 8px; text-align: left; }
        th { background: #f8fafc; font-weight: 600; }
        .badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-weight: bold; font-size: 11px; }
        .badge.pending { background: #fef08a; color: #854d0e; }
        .badge.sent { background: #bbf7d0; color: #166534; }
        .badge.skipped { background: #e2e8f0; color: #475569; }
        .badge.failed { background: #fecaca; color: #991b1b; }
    </style>
</head>
<body>
<main>
    <h1>🔍 ChiyaBreak Live Notification Debugger</h1>
    <p>Target User: <strong><?= h($allowedRecipient) ?></strong> | Resend Key Status: <strong><?= $apiKey !== '' ? 'Configured' : 'MISSING (configure private server settings)' ?></strong></p>

    <?php if ($message): ?>
        <div class="msg"><?= h($message) ?></div>
    <?php endif; ?>

    <h2>⚡ Live Diagnostics & Simulation Actions</h2>
    <div class="btn-group">
        <form method="post" style="display:inline;">
            <button class="primary" name="action" value="test_follow">1. Simulate Follow Event</button>
            <button class="secondary" name="action" value="test_message">2. Simulate Chat Message Event</button>
            <button class="danger" name="action" value="run_worker_now">3. Force Run Email Worker Now</button>
        </form>
    </div>

    <h2>1. Email Preferences Record</h2>
    <?php if ($userPref): ?>
        <p>Email Enabled: <strong><?= $userPref['email_enabled'] ? 'ON (1)' : 'OFF (0)' ?></strong> | Follows: <strong><?= $userPref['email_follow'] ? 'ON' : 'OFF' ?></strong> | Waves: <strong><?= $userPref['email_wave'] ? 'ON' : 'OFF' ?></strong> | Messages: <strong><?= $userPref['email_message'] ? 'ON' : 'OFF' ?></strong></p>
    <?php else: ?>
        <p style="color: #64748b;">No preferences row saved yet (System will auto-default to ENABLED for registered customers).</p>
    <?php endif; ?>

    <h2>2. Recent Queue Items (`notification_email_queue`)</h2>
    <?php if ($recentQueue): ?>
        <table>
            <thead>
                <tr>
                    <th>Queue ID</th>
                    <th>Notif ID</th>
                    <th>Event</th>
                    <th>Status</th>
                    <th>Created At</th>
                    <th>Attempts</th>
                    <th>Last Error</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($recentQueue as $q): ?>
                    <tr>
                        <td>#<?= h($q['id']) ?></td>
                        <td>#<?= h($q['notification_id']) ?></td>
                        <td><?= h($q['event_type']) ?></td>
                        <td><span class="badge <?= h($q['status']) ?>"><?= h(strtoupper($q['status'])) ?></span></td>
                        <td><?= h($q['created_at']) ?></td>
                        <td><?= h($q['attempts']) ?></td>
                        <td style="color:#dc2626; font-size:11px;"><?= h($q['last_error'] ?: 'None') ?></td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    <?php else: ?>
        <p>No queued notification entries found for this recipient.</p>
    <?php endif; ?>

    <h2>3. Recent Notifications Table (`notifications`)</h2>
    <?php if ($recentNotifications): ?>
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Type</th>
                    <th>Title</th>
                    <th>Is Read</th>
                    <th>Created At</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($recentNotifications as $n): ?>
                    <tr>
                        <td>#<?= h($n['id']) ?></td>
                        <td><?= h($n['type']) ?></td>
                        <td><?= h($n['title']) ?></td>
                        <td><?= $n['is_read'] ? 'Yes (Read)' : 'No (Unread)' ?></td>
                        <td><?= h($n['created_at']) ?></td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    <?php else: ?>
        <p>No notifications found in database for this recipient.</p>
    <?php endif; ?>

</main>
</body>
</html>
