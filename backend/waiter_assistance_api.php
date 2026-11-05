<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/staff_auth.php';
require_once __DIR__ . '/email_notification_common.php';

function waiterAssistanceRespond($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload);
    exit;
}

function waiterAssistanceInput() {
    $raw = file_get_contents('php://input');
    $input = json_decode($raw ?: '', true);
    if (!is_array($input)) {
        waiterAssistanceRespond(400, [
            'status' => 'error',
            'message' => 'A valid JSON request body is required',
        ]);
    }
    return $input;
}

$emailQueuedCount = 0;
$notificationFailed = false;
try {
    $conn->query("CREATE TABLE IF NOT EXISTS waiter_assistance_requests (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(100) NOT NULL,
        table_number INT UNSIGNED NOT NULL,
        customer_name VARCHAR(255) NOT NULL,
        request_text TEXT NOT NULL,
        status VARCHAR(32) NOT NULL DEFAULT 'Requested',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        completed_at TIMESTAMP NULL DEFAULT NULL,
        INDEX idx_waiter_assistance_tenant_status
            (tenant_id, status, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

    $action = (string)($_GET['action'] ?? '');
    if ($action === 'create' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = waiterAssistanceInput();
        $tenantId = trim((string)($input['tenant_id'] ?? ''));
        $tableNumber = filter_var(
            $input['table_number'] ?? null,
            FILTER_VALIDATE_INT
        );
        $customerName = trim((string)($input['customer_name'] ?? 'Guest Diner'));
        $requestText = trim((string)($input['request_text'] ?? ''));
        if ($tenantId === '' || strlen($tenantId) > 100 ||
            $tableNumber === false || $tableNumber < 1 ||
            $customerName === '' || strlen($customerName) > 255 ||
            $requestText === '' || strlen($requestText) > 2000) {
            waiterAssistanceRespond(400, [
                'status' => 'error',
                'message' => 'Provide a restaurant, table, customer name, and valid assistance request',
            ]);
        }

        $tenantStmt = $conn->prepare(
            'SELECT tenant_id FROM tenants
             WHERE tenant_id COLLATE utf8mb4_general_ci =
                   ? COLLATE utf8mb4_general_ci
             LIMIT 1'
        );
        $tenantStmt->bind_param('s', $tenantId);
        $tenantStmt->execute();
        $tenant = $tenantStmt->get_result()->fetch_assoc();
        $tenantStmt->close();
        if (!$tenant) {
            waiterAssistanceRespond(404, [
                'status' => 'error',
                'message' => 'Restaurant was not found',
            ]);
        }

        $insert = $conn->prepare(
            "INSERT INTO waiter_assistance_requests
             (tenant_id, table_number, customer_name, request_text)
             VALUES (?, ?, ?, ?)"
        );
        $insert->bind_param(
            'siss',
            $tenantId,
            $tableNumber,
            $customerName,
            $requestText
        );
        $insert->execute();
        $requestId = (int)$conn->insert_id;
        $insert->close();

        try {
            $waiters = $conn->prepare(
                "SELECT DISTINCT LOWER(TRIM(email)) AS email
                 FROM users
                 WHERE tenant_id COLLATE utf8mb4_general_ci =
                       ? COLLATE utf8mb4_general_ci
                   AND LOWER(TRIM(role)) = 'waiter'
                   AND email IS NOT NULL AND TRIM(email) <> ''"
            );
            $waiters->bind_param('s', $tenantId);
            $waiters->execute();
            $recipients = $waiters->get_result()->fetch_all(MYSQLI_ASSOC);
            $waiters->close();

            $title = "Waiter needed at Table $tableNumber";
            $message = "$customerName requested assistance: $requestText";
            foreach ($recipients as $recipient) {
                $email = strtolower(trim((string)$recipient['email']));
                if (!filter_var($email, FILTER_VALIDATE_EMAIL)) continue;

                $notification = $conn->prepare(
                    "INSERT INTO notifications
                     (tenant_id, user_id, title, message, type)
                     VALUES (?, ?, ?, ?, 'waiter_assistance')"
                );
                $notification->bind_param(
                    'ssss',
                    $tenantId,
                    $email,
                    $title,
                    $message
                );
                $notification->execute();
                $notificationId = (int)$conn->insert_id;
                $notification->close();

                if (queueEmailNotification(
                    $conn,
                    $tenantId,
                    $email,
                    $notificationId,
                    'waiter_assistance'
                )) {
                    $emailQueuedCount++;
                }
            }
        } catch (Throwable $notificationError) {
            $notificationFailed = true;
            error_log(
                "Waiter assistance request #$requestId was saved, but email " .
                "notification failed: " . $notificationError->getMessage()
            );
        }

        waiterAssistanceRespond(201, [
            'status' => 'success',
            'message' => $notificationFailed
                ? 'Request saved, but waiter email notification could not be queued'
                : ($emailQueuedCount > 0
                    ? 'Waiter email notification queued'
                    : 'Request saved, but no waiter email notification is enabled'),
            'email_queued_count' => $emailQueuedCount,
            'notification_failed' => $notificationFailed,
            'request_id' => $requestId,
        ]);
    }

    if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'POST'], true)) {
        waiterAssistanceRespond(405, [
            'status' => 'error',
            'message' => 'GET or POST is required',
        ]);
    }
    $auth = requireAuth($conn, ['waiter', 'kitchen']);
    $staff = $auth['user'];
    $tenantId = (string)$staff['tenant_id'];
    if ($action === 'list' && $_SERVER['REQUEST_METHOD'] === 'GET') {
        $requestedTenant = trim((string)($_GET['tenant_id'] ?? ''));
        if ($requestedTenant !== '' && $requestedTenant !== $tenantId) {
            waiterAssistanceRespond(403, [
                'status' => 'error',
                'message' => 'Tenant does not match the authenticated staff session',
            ]);
        }
        $stmt = $conn->prepare(
            "SELECT id, tenant_id, table_number, customer_name,
                    CONCAT('ASSISTANCE: ', request_text) AS transcript,
                    status, created_at, 'waiter_assistance' AS request_source
             FROM waiter_assistance_requests
             WHERE tenant_id = ? AND status <> 'Completed'
             ORDER BY created_at DESC, id DESC"
        );
        $stmt->bind_param('s', $tenantId);
        $stmt->execute();
        $requests = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        waiterAssistanceRespond(200, [
            'status' => 'success',
            'orders' => $requests,
        ]);
    }

    if ($action === 'complete' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = waiterAssistanceInput();
        $requestId = (int)($input['request_id'] ?? 0);
        if ($requestId <= 0) {
            waiterAssistanceRespond(400, [
                'status' => 'error',
                'message' => 'A valid request_id is required',
            ]);
        }
        $stmt = $conn->prepare(
            "UPDATE waiter_assistance_requests
             SET status = 'Completed', completed_at = CURRENT_TIMESTAMP
             WHERE id = ? AND tenant_id = ? AND status <> 'Completed'"
        );
        $stmt->bind_param('is', $requestId, $tenantId);
        $stmt->execute();
        $updated = $stmt->affected_rows === 1;
        $stmt->close();
        if (!$updated) {
            waiterAssistanceRespond(404, [
                'status' => 'error',
                'message' => 'Active waiter assistance request was not found',
            ]);
        }
        waiterAssistanceRespond(200, [
            'status' => 'success',
            'message' => 'Assistance request completed',
        ]);
    }

    waiterAssistanceRespond(400, [
        'status' => 'error',
        'message' => 'Unknown waiter assistance action',
    ]);
} catch (Throwable $error) {
    error_log('Waiter assistance API failed: ' . $error->getMessage());
    waiterAssistanceRespond(500, [
        'status' => 'error',
        'message' => 'Could not process waiter assistance request',
    ]);
}
?>
