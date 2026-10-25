<?php

function issueCustomerSession($conn, $email, $tenantId) {
    $token = bin2hex(random_bytes(32));
    $tokenHash = hash('sha256', $token);
    $stmt = $conn->prepare("INSERT INTO customer_auth_sessions
        (token_hash, tenant_id, email, expires_at)
        VALUES (?, ?, ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 30 DAY))");
    if (!$stmt) throw new Exception("Could not create customer session");
    $stmt->bind_param("sss", $tokenHash, $tenantId, $email);
    if (!$stmt->execute()) throw new Exception("Could not create customer session");
    $stmt->close();
    return $token;
}

function authenticatedCustomerEmail($conn, $tenantId) {
    $tokenHash = customerSessionTokenHash();
    if ($tokenHash === null) return null;

    $stmt = $conn->prepare("SELECT email FROM customer_auth_sessions
        WHERE token_hash = ? AND tenant_id = ? AND expires_at > CURRENT_TIMESTAMP LIMIT 1");
    if (!$stmt) throw new Exception("Could not verify customer session");
    $stmt->bind_param("ss", $tokenHash, $tenantId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    return $row ? $row['email'] : null;
}

function customerSessionTokenHash() {
    $authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if ($authorization === '' && function_exists('getallheaders')) {
        $headers = getallheaders();
        $authorization = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    }
    if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim($authorization), $matches)) {
        return null;
    }
    return hash('sha256', $matches[1]);
}

function resendEmailConfig() {
    $privateConfig = [];
    $configPaths = [
        dirname(__DIR__, 2) . DIRECTORY_SEPARATOR . 'resend_config.php',
        __DIR__ . DIRECTORY_SEPARATOR . 'resend_config.php'
    ];
    foreach ($configPaths as $configPath) {
        if (is_readable($configPath)) {
            $loadedConfig = require $configPath;
            if (is_array($loadedConfig)) {
                $privateConfig = $loadedConfig;
                break;
            }
        }
    }

    $apiKey = getenv('RESEND_API_KEY')
        ?: ($privateConfig['RESEND_API_KEY'] ?? $privateConfig['api_key'] ?? '');
    $from = getenv('RESEND_FROM_EMAIL')
        ?: ($privateConfig['RESEND_FROM_EMAIL'] ?? $privateConfig['from'] ?? 'noreply@startupsgo.tech');
    return [
        'api_key' => trim((string)$apiKey),
        'from' => trim((string)$from)
    ];
}

function releaseQueuedEmailNotification($conn, $tenantId, $userId, $notificationId) {
    $release = $conn->prepare("UPDATE notification_email_queue
        SET status = 'pending', processing_started_at = NULL
        WHERE tenant_id = ? AND user_id = ? AND notification_id = ? AND status = 'processing'");
    if (!$release) return;
    $release->bind_param('ssi', $tenantId, $userId, $notificationId);
    $release->execute();
    $release->close();
}

function sendQueuedEmailNotificationImmediately($conn, $tenantId, $userId, $notificationId, $eventType) {
    $config = resendEmailConfig();
    if ($config['api_key'] === '' || !function_exists('curl_init')) {
        error_log('Immediate email notification unavailable: Resend API key or PHP cURL is missing; notification remains queued.');
        return;
    }

    $claim = $conn->prepare("UPDATE notification_email_queue
        SET status = 'processing', processing_started_at = CURRENT_TIMESTAMP
        WHERE tenant_id = ? AND user_id = ? AND notification_id = ? AND status = 'pending'");
    if (!$claim) {
        error_log('Could not claim queued email notification for immediate delivery.');
        return;
    }
    $claim->bind_param('ssi', $tenantId, $userId, $notificationId);
    if (!$claim->execute()) {
        error_log('Could not claim queued email notification for immediate delivery.');
        $claim->close();
        return;
    }
    $claimed = $claim->affected_rows === 1;
    $claim->close();
    if (!$claimed) return;

    $notification = $conn->prepare("SELECT title, message FROM notifications
        WHERE id = ? AND tenant_id = ? LIMIT 1");
    if (!$notification) {
        releaseQueuedEmailNotification($conn, $tenantId, $userId, $notificationId);
        error_log('Could not load notification for immediate email delivery.');
        return;
    }
    $notification->bind_param('is', $notificationId, $tenantId);
    if (!$notification->execute()) {
        error_log('Could not load notification for immediate email delivery.');
        $notification->close();
        releaseQueuedEmailNotification($conn, $tenantId, $userId, $notificationId);
        return;
    }
    $event = $notification->get_result()->fetch_assoc();
    $notification->close();
    if (!$event) {
        releaseQueuedEmailNotification($conn, $tenantId, $userId, $notificationId);
        error_log('Queued email notification has no matching app notification.');
        return;
    }

    $title = trim((string)$event['title']);
    $detail = $eventType === 'message'
        ? 'You have a new chat message. Open the app to read it.'
        : trim((string)$event['message']);
    if ($detail === '') $detail = $title;

    $payload = json_encode([
        'from' => $config['from'],
        'to' => [$userId],
        'subject' => 'ChiyaBreak notification: ' . $title,
        'text' => $title . "\n" . $detail,
        'html' => '<p><strong>' . htmlspecialchars($title, ENT_QUOTES, 'UTF-8') .
            '</strong></p><p>' . htmlspecialchars($detail, ENT_QUOTES, 'UTF-8') . '</p>'
    ]);
    if ($payload === false) {
        $sendError = 'Could not encode email payload.';
        $success = false;
    } else {
        $curl = curl_init('https://api.resend.com/emails');
        curl_setopt_array($curl, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $payload,
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $config['api_key'],
                'Content-Type: application/json'
            ],
            CURLOPT_TIMEOUT => 12
        ]);
        $response = curl_exec($curl);
        $statusCode = (int)curl_getinfo($curl, CURLINFO_HTTP_CODE);
        $curlError = curl_error($curl);
        curl_close($curl);
        $success = $response !== false && $statusCode >= 200 && $statusCode < 300;
        $sendError = $success ? '' : substr($curlError ?: (string)$response, 0, 1000);
    }

    if ($success) {
        $update = $conn->prepare("UPDATE notification_email_queue
            SET status = 'sent', sent_at = CURRENT_TIMESTAMP,
                processing_started_at = NULL, last_error = NULL
            WHERE tenant_id = ? AND user_id = ? AND notification_id = ? AND status = 'processing'");
        if ($update) {
            $update->bind_param('ssi', $tenantId, $userId, $notificationId);
            if (!$update->execute()) {
                error_log('Email was accepted by Resend but queue status could not be updated.');
            }
            $update->close();
        }
        return;
    }

    $update = $conn->prepare("UPDATE notification_email_queue
        SET attempts = attempts + 1, processing_started_at = NULL,
            last_error = ?, available_at = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 5 MINUTE),
            status = IF(attempts >= 5, 'failed', 'pending')
        WHERE tenant_id = ? AND user_id = ? AND notification_id = ? AND status = 'processing'");
    if ($update) {
        $update->bind_param('sssi', $sendError, $tenantId, $userId, $notificationId);
        if (!$update->execute()) {
            error_log('Immediate email delivery failed and the queue retry state could not be saved.');
        }
        $update->close();
    }
    error_log('Immediate email notification delivery failed; it remains queued for retry.');
}

function queueEmailNotification($conn, $tenantId, $userId, $notificationId, $eventType) {
    $preferenceColumn = [
        'follow' => 'email_follow',
        'follow_back' => 'email_follow',
        'wave' => 'email_wave',
        'message' => 'email_message'
    ][$eventType] ?? null;
    if ($preferenceColumn === null) return;

    $cleanUserId = strtolower(trim((string)$userId));
    if ($cleanUserId === '') return;

    // Resolve email if cleanUserId is not already an email address
    if (!filter_var($cleanUserId, FILTER_VALIDATE_EMAIL)) {
        $resolveStmt = $conn->prepare("SELECT email FROM customers WHERE tenant_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci AND (LOWER(email) = LOWER(?) OR id = ?) LIMIT 1");
        if ($resolveStmt) {
            $resolveStmt->bind_param("sss", $tenantId, $cleanUserId, $cleanUserId);
            $resolveStmt->execute();
            $resRow = $resolveStmt->get_result()->fetch_assoc();
            $resolveStmt->close();
            if ($resRow && !empty($resRow['email'])) {
                $cleanUserId = strtolower(trim($resRow['email']));
            }
        }
    }

    if (!filter_var($cleanUserId, FILTER_VALIDATE_EMAIL)) {
        return; // Recipient is not a valid email address
    }

    // Check preferences
    $preference = $conn->prepare("SELECT email_enabled, $preferenceColumn AS event_enabled
        FROM customer_notification_email_preferences
        WHERE tenant_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci
          AND LOWER(email) COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci LIMIT 1");
    if (!$preference) throw new Exception("Could not check email notification preferences");
    $preference->bind_param("ss", $tenantId, $cleanUserId);
    $preference->execute();
    $settings = $preference->get_result()->fetch_assoc();
    $preference->close();

    if (!filter_var($cleanUserId, FILTER_VALIDATE_EMAIL)) return;
    if (!$settings || (int)$settings['email_enabled'] !== 1 || (int)$settings['event_enabled'] !== 1) {
        return;
    }

    $stmt = $conn->prepare("INSERT IGNORE INTO notification_email_queue
        (tenant_id, user_id, notification_id, event_type, available_at)
        VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)");
    if (!$stmt) throw new Exception("Could not queue email notification");
    $stmt->bind_param("ssis", $tenantId, $cleanUserId, $notificationId, $eventType);
    if (!$stmt->execute()) throw new Exception("Could not queue email notification");
    $queued = $stmt->affected_rows === 1;
    $stmt->close();
    if ($queued && $eventType !== 'message') {
        sendQueuedEmailNotificationImmediately($conn, $tenantId, $cleanUserId, $notificationId, $eventType);
    }
}
