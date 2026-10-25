<?php
if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/email_notification_common.php';

$conn->query("DELETE FROM customer_auth_sessions
    WHERE expires_at <= CURRENT_TIMESTAMP LIMIT 500");
$conn->query("UPDATE notification_email_queue q
    LEFT JOIN customer_notification_email_preferences p
        ON p.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci
       AND LOWER(p.email) COLLATE utf8mb4_general_ci = LOWER(q.user_id) COLLATE utf8mb4_general_ci
    SET q.status = 'skipped'
    WHERE q.status = 'pending' AND
        (p.email_enabled = 0
            OR (p.email_enabled = 1 AND q.event_type IN ('follow', 'follow_back') AND p.email_follow = 0)
            OR (p.email_enabled = 1 AND q.event_type = 'wave' AND p.email_wave = 0)
            OR (p.email_enabled = 1 AND q.event_type = 'message' AND p.email_message = 0))");
$conn->query("UPDATE notification_email_queue q
    INNER JOIN notifications n
        ON n.id = q.notification_id
        AND n.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci
    SET q.status = 'acknowledged'
    WHERE q.status = 'pending' AND q.event_type = 'message'
        AND ((n.is_read = 1
                AND q.created_at > DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 MINUTE))
            OR EXISTS (
            SELECT 1 FROM chat_messages cm
            WHERE cm.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci
                AND LOWER(cm.sender_id) COLLATE utf8mb4_general_ci = LOWER(q.user_id) COLLATE utf8mb4_general_ci
                AND LOWER(cm.receiver_id) COLLATE utf8mb4_general_ci = LOWER(n.sender_id) COLLATE utf8mb4_general_ci
                AND cm.created_at BETWEEN n.created_at
                    AND DATE_ADD(n.created_at, INTERVAL 1 MINUTE)
        ))");
$conn->query("UPDATE notification_email_queue
    SET status = 'pending', available_at = CURRENT_TIMESTAMP, processing_started_at = NULL
    WHERE status = 'processing'
        AND (processing_started_at IS NULL
            OR processing_started_at < DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 10 MINUTE))");

$resendConfig = resendEmailConfig();
$apiKey = $resendConfig['api_key'];
$from = $resendConfig['from'];
if ($apiKey === '') {
    fwrite(STDERR, "Configure RESEND_API_KEY or the private resend_config.php before running the worker.\n");
    exit(1);
}

$sql = "SELECT q.id AS queue_id, q.tenant_id, q.user_id, q.notification_id,
        q.event_type, n.title, n.message, COALESCE(c.email, q.user_id) AS recipient
    FROM notification_email_queue q
    INNER JOIN notifications n ON n.id = q.notification_id AND n.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci
    LEFT JOIN customer_notification_email_preferences p
        ON p.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci AND p.email COLLATE utf8mb4_general_ci = q.user_id COLLATE utf8mb4_general_ci
    LEFT JOIN customers c ON LOWER(c.email) COLLATE utf8mb4_general_ci = LOWER(q.user_id) COLLATE utf8mb4_general_ci
    WHERE q.status = 'pending' AND q.available_at <= CURRENT_TIMESTAMP
        AND (p.email_enabled IS NULL OR p.email_enabled = 1)
        AND (p.email_follow IS NULL OR p.email_follow = 1 OR q.event_type NOT IN ('follow', 'follow_back'))
        AND (p.email_wave IS NULL OR p.email_wave = 1 OR q.event_type != 'wave')
        AND (p.email_message IS NULL OR p.email_message = 1 OR q.event_type != 'message')
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
    ORDER BY q.tenant_id, q.user_id, q.id LIMIT 500";

$result = $conn->query($sql);
if (!$result) {
    fwrite(STDERR, "Could not load pending email notifications: " . $conn->error . "\n");
    exit(1);
}

$groups = [];
while ($row = $result->fetch_assoc()) {
    $key = $row['tenant_id'] . "\0" . strtolower($row['user_id']);
    $groups[$key][] = $row;
}

$sentCount = 0;
function bindDynamicParams($statement, $types, &$values) {
    $arguments = [$types];
    foreach ($values as $index => &$value) {
        $arguments[] = &$values[$index];
    }
    unset($value);
    return call_user_func_array([$statement, 'bind_param'], $arguments);
}

foreach ($groups as $events) {
    $claimedEvents = [];
    foreach ($events as $event) {
        $queueId = (int)$event['queue_id'];
        $claim = $conn->prepare("UPDATE notification_email_queue
            SET status = 'processing', processing_started_at = CURRENT_TIMESTAMP
            WHERE status = 'pending' AND id = ?");
        $claim->bind_param('i', $queueId);
        $claim->execute();
        if ($claim->affected_rows === 1) {
            $claimedEvents[] = $event;
        }
        $claim->close();
    }
    $events = $claimedEvents;
    if (!$events) continue;

    $ids = array_map('intval', array_column($events, 'queue_id'));
    $placeholders = implode(',', array_fill(0, count($ids), '?'));
    $types = str_repeat('i', count($ids));

    $check = $conn->prepare("SELECT q.id
        FROM notification_email_queue q
        INNER JOIN notifications n
            ON n.id = q.notification_id
            AND n.tenant_id COLLATE utf8mb4_general_ci = q.tenant_id COLLATE utf8mb4_general_ci
        WHERE q.status = 'processing' AND q.id IN ($placeholders)
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
            ))");
    bindDynamicParams($check, $types, $ids);
    $check->execute();
    $eligibleIds = [];
    $checkResult = $check->get_result();
    while ($row = $checkResult->fetch_assoc()) {
        $eligibleIds[] = (int)$row['id'];
    }
    $check->close();
    if (count($eligibleIds) !== count($ids)) {
        $ineligibleIds = array_values(array_diff($ids, $eligibleIds));
        if ($ineligibleIds) {
            $ineligiblePlaceholders = implode(',', array_fill(0, count($ineligibleIds), '?'));
            $ineligibleTypes = str_repeat('i', count($ineligibleIds));
            $acknowledge = $conn->prepare("UPDATE notification_email_queue
                SET status = 'acknowledged', processing_started_at = NULL
                WHERE status = 'processing' AND id IN ($ineligiblePlaceholders)");
            bindDynamicParams($acknowledge, $ineligibleTypes, $ineligibleIds);
            $acknowledge->execute();
            $acknowledge->close();
        }
        $eligibleIdSet = array_fill_keys($eligibleIds, true);
        $events = array_values(array_filter($events, function ($event) use ($eligibleIdSet) {
            return isset($eligibleIdSet[(int)$event['queue_id']]);
        }));
    }
    if (!$events) continue;

    $lines = [];
    $htmlLines = [];
    foreach ($events as $event) {
        $title = trim((string)$event['title']);
        $detail = $event['event_type'] === 'message'
            ? 'You have a new chat message. Open the app to read it.'
            : trim((string)$event['message']);
        if ($detail === '') $detail = $title;
        $lines[] = $title . "\n" . $detail;
        $htmlLines[] = '<li><strong>' . htmlspecialchars($title, ENT_QUOTES, 'UTF-8') .
            '</strong><br>' . htmlspecialchars($detail, ENT_QUOTES, 'UTF-8') . '</li>';
    }

    $recipient = (string)$events[0]['recipient'];
    if (!filter_var($recipient, FILTER_VALIDATE_EMAIL)) {
        $sendError = 'Invalid recipient address';
        $success = false;
    } else {
        $payload = json_encode([
            'from' => $from,
            'to' => [$recipient],
            'subject' => count($lines) === 1 ? 'You have a new social notification' : 'You have new social notifications',
            'text' => "You have notifications waiting in the app:\n\n" . implode("\n\n", $lines),
            'html' => '<p>You have notifications waiting in the app:</p><ul>' .
                implode('', $htmlLines) . '</ul><p>Open the app to respond.</p>'
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
        $success = $response !== false && $statusCode >= 200 && $statusCode < 300;
        $sendError = $success ? '' : substr($curlError ?: (string)$response, 0, 1000);
    }

    $sendIds = array_map('intval', array_column($events, 'queue_id'));
    $sendPlaceholders = implode(',', array_fill(0, count($sendIds), '?'));
    $sendTypes = str_repeat('i', count($sendIds));
    if ($success) {
        $update = $conn->prepare("UPDATE notification_email_queue
            SET status = 'sent', sent_at = CURRENT_TIMESTAMP,
                processing_started_at = NULL, last_error = NULL
            WHERE status = 'processing' AND id IN ($sendPlaceholders)");
        bindDynamicParams($update, $sendTypes, $sendIds);
        $update->execute();
        $update->close();
        $sentCount++;
    } else {
        $update = $conn->prepare("UPDATE notification_email_queue
            SET attempts = attempts + 1, processing_started_at = NULL,
                last_error = ?, available_at = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 5 MINUTE),
                status = IF(attempts >= 5, 'failed', 'pending')
            WHERE status = 'processing' AND id IN ($sendPlaceholders)");
        $failureParams = array_merge([$sendError], $sendIds);
        bindDynamicParams($update, 's' . $sendTypes, $failureParams);
        $update->execute();
        $update->close();
        fwrite(STDERR, "Resend delivery failed for one recipient group.\n");
    }
}

echo "Sent email notification digests: $sentCount\n";
$conn->close();
