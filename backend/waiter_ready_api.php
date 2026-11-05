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

function waiterReadyRespond($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload);
    exit;
}

function waiterReadyInput() {
    $input = json_decode(file_get_contents('php://input') ?: '', true);
    if (!is_array($input)) {
        waiterReadyRespond(400, [
            'status' => 'error',
            'message' => 'A valid JSON request body is required',
        ]);
    }
    return $input;
}

try {
    if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'POST'], true)) {
        waiterReadyRespond(405, [
            'status' => 'error',
            'message' => 'GET or POST is required',
        ]);
    }

    $auth = requireAuth($conn, ['waiter', 'kitchen']);
    $staff = $auth['user'];
    $tenantId = (string)$staff['tenant_id'];
    $staffId = (int)$staff['id'];
    $staffName = trim((string)($staff['name'] ?? 'Waiter'));
    $action = (string)($_GET['action'] ?? '');

    $conn->query("CREATE TABLE IF NOT EXISTS waiter_ready_tasks (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(100) NOT NULL,
        order_id BIGINT UNSIGNED NOT NULL,
        table_number INT UNSIGNED NOT NULL,
        order_number INT UNSIGNED DEFAULT NULL,
        status VARCHAR(32) NOT NULL DEFAULT 'pending',
        accepted_by_staff_id BIGINT UNSIGNED DEFAULT NULL,
        accepted_by_name VARCHAR(255) DEFAULT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        accepted_at TIMESTAMP NULL DEFAULT NULL,
        completed_at TIMESTAMP NULL DEFAULT NULL,
        UNIQUE KEY uniq_waiter_ready_tenant_order (tenant_id, order_id),
        INDEX idx_waiter_ready_tenant_status (tenant_id, status, created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

    if ($action === 'list' && $_SERVER['REQUEST_METHOD'] === 'GET') {
        if ($staff['role'] !== 'waiter') {
            waiterReadyRespond(403, [
                'status' => 'error',
                'message' => 'Only waiter accounts can view service tasks',
            ]);
        }
        $stmt = $conn->prepare(
            "SELECT task.id, task.order_id, task.table_number, task.order_number,
                    task.status, task.accepted_by_staff_id, task.accepted_by_name,
                    task.created_at, task.accepted_at,
                    COALESCE(order_row.tenant_order_number, order_row.id) AS display_order_number
             FROM waiter_ready_tasks task
             INNER JOIN orders order_row
                ON order_row.id = task.order_id
               AND order_row.tenant_id COLLATE utf8mb4_general_ci =
                   task.tenant_id COLLATE utf8mb4_general_ci
             WHERE task.tenant_id = ?
               AND LOWER(order_row.status) NOT IN ('cancelled', 'canceled', 'voided', 'settled')
               AND (task.status = 'pending'
                    OR (task.status = 'accepted' AND task.accepted_by_staff_id = ?))
             ORDER BY task.created_at DESC, task.id DESC"
        );
        $stmt->bind_param('si', $tenantId, $staffId);
        $stmt->execute();
        $tasks = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        waiterReadyRespond(200, [
            'status' => 'success',
            'tasks' => $tasks,
        ]);
    }

    if ($action === 'notify' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        if ($staff['role'] !== 'kitchen') {
            waiterReadyRespond(403, [
                'status' => 'error',
                'message' => 'Only kitchen staff can notify waiters about ready orders',
            ]);
        }
        $input = waiterReadyInput();
        $orderId = filter_var($input['order_id'] ?? null, FILTER_VALIDATE_INT);
        if ($orderId === false || $orderId <= 0) {
            waiterReadyRespond(400, [
                'status' => 'error',
                'message' => 'A valid order_id is required',
            ]);
        }

        $orderStmt = $conn->prepare(
            "SELECT order_row.id, order_row.status, order_row.tenant_order_number,
                    COALESCE(table_row.table_number, session_row.table_number,
                             order_row.table_id, 1) AS table_number
             FROM orders order_row
             LEFT JOIN restaurant_tables table_row
                ON table_row.id = order_row.table_id
               AND table_row.tenant_id COLLATE utf8mb4_general_ci =
                   order_row.tenant_id COLLATE utf8mb4_general_ci
             LEFT JOIN dining_sessions session_row
                ON session_row.id = order_row.session_id
               AND session_row.tenant_id COLLATE utf8mb4_general_ci =
                   order_row.tenant_id COLLATE utf8mb4_general_ci
             WHERE order_row.id = ? AND order_row.tenant_id = ?
             LIMIT 1"
        );
        $orderStmt->bind_param('is', $orderId, $tenantId);
        $orderStmt->execute();
        $order = $orderStmt->get_result()->fetch_assoc();
        $orderStmt->close();
        if (!$order) {
            waiterReadyRespond(404, [
                'status' => 'error',
                'message' => 'Order was not found for this restaurant',
            ]);
        }
        if (strtolower((string)$order['status']) !== 'ready') {
            waiterReadyRespond(409, [
                'status' => 'error',
                'message' => 'Only orders marked Ready can be sent to waiters',
            ]);
        }

        $conn->begin_transaction();
        try {
            $insert = $conn->prepare(
                'INSERT IGNORE INTO waiter_ready_tasks
                    (tenant_id, order_id, table_number, order_number)
                 VALUES (?, ?, ?, ?)'
            );
            $tableNumber = (int)$order['table_number'];
            $orderNumber = $order['tenant_order_number'] !== null
                ? (int)$order['tenant_order_number']
                : null;
            $insert->bind_param('siii', $tenantId, $orderId, $tableNumber, $orderNumber);
            $insert->execute();
            $created = $insert->affected_rows === 1;
            $insert->close();

            $taskStmt = $conn->prepare(
                'SELECT id, status FROM waiter_ready_tasks
                 WHERE tenant_id = ? AND order_id = ? FOR UPDATE'
            );
            $taskStmt->bind_param('si', $tenantId, $orderId);
            $taskStmt->execute();
            $task = $taskStmt->get_result()->fetch_assoc();
            $taskStmt->close();
            if (!$task) {
                throw new RuntimeException('Could not create or load the waiter service task');
            }
            if (!$created && $task['status'] === 'completed') {
                $conn->commit();
                waiterReadyRespond(409, [
                    'status' => 'error',
                    'message' => 'This ready order has already been served',
                ]);
            }
            $conn->commit();
        } catch (Throwable $transactionError) {
            $conn->rollback();
            throw $transactionError;
        }

        if (!$created) {
            waiterReadyRespond(200, [
                'status' => 'success',
                'message' => $task['status'] === 'accepted'
                    ? 'A waiter has already accepted this order'
                    : 'Waiters have already been notified about this order',
                'already_notified' => true,
                'accepted' => $task['status'] === 'accepted',
            ]);
        }

        $emailQueuedCount = 0;
        $notificationFailed = false;
        try {
            $waitersStmt = $conn->prepare(
                "SELECT DISTINCT LOWER(TRIM(email)) AS email
                 FROM users
                 WHERE tenant_id = ?
                   AND LOWER(TRIM(role)) = 'waiter'
                   AND email IS NOT NULL AND TRIM(email) <> ''"
            );
            $waitersStmt->bind_param('s', $tenantId);
            $waitersStmt->execute();
            $waiters = $waitersStmt->get_result()->fetch_all(MYSQLI_ASSOC);
            $waitersStmt->close();

            $displayOrderNumber = $orderNumber ?? $orderId;
            $title = "Order #$displayOrderNumber is ready to serve";
            $message = "Table T-$tableNumber: the kitchen has marked this order ready. Accept it in the waiter app to take responsibility for serving it.";
            foreach ($waiters as $waiter) {
                $email = strtolower(trim((string)$waiter['email']));
                if (!filter_var($email, FILTER_VALIDATE_EMAIL)) continue;

                try {
                    $notification = $conn->prepare(
                        "INSERT INTO notifications
                            (tenant_id, user_id, title, message, type)
                         VALUES (?, ?, ?, ?, 'staff_order')"
                    );
                    $notification->bind_param('ssss', $tenantId, $email, $title, $message);
                    $notification->execute();
                    $notificationId = (int)$conn->insert_id;
                    $notification->close();

                    if (queueEmailNotification(
                        $conn,
                        $tenantId,
                        $email,
                        $notificationId,
                        'staff_order'
                    )) {
                        $emailQueuedCount++;
                    }
                } catch (Throwable $recipientError) {
                    $notificationFailed = true;
                    error_log(
                        "Ready order task #{$task['id']} email failed for tenant " .
                        "$tenantId: " . $recipientError->getMessage()
                    );
                }
            }
        } catch (Throwable $notificationError) {
            $notificationFailed = true;
            error_log(
                "Ready order task #{$task['id']} was created, but waiter notification " .
                "delivery failed: " . $notificationError->getMessage()
            );
        }

        waiterReadyRespond(201, [
            'status' => 'success',
            'message' => $notificationFailed
                ? 'Waiter service task was created, but some email notifications failed'
                : ($emailQueuedCount > 0
                    ? 'Waiters have been notified'
                    : 'In-app service task was created, but no waiter email was queued'),
            'task_id' => (int)$task['id'],
            'email_queued_count' => $emailQueuedCount,
            'notification_failed' => $notificationFailed,
        ]);
    }

    if ($action === 'accept' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        if ($staff['role'] !== 'waiter') {
            waiterReadyRespond(403, [
                'status' => 'error',
                'message' => 'Only waiters can accept service tasks',
            ]);
        }
        $input = waiterReadyInput();
        $taskId = filter_var($input['task_id'] ?? null, FILTER_VALIDATE_INT);
        if ($taskId === false || $taskId <= 0) {
            waiterReadyRespond(400, [
                'status' => 'error',
                'message' => 'A valid task_id is required',
            ]);
        }
        $stmt = $conn->prepare(
            "UPDATE waiter_ready_tasks
             SET status = 'accepted', accepted_by_staff_id = ?,
                 accepted_by_name = ?, accepted_at = CURRENT_TIMESTAMP
             WHERE id = ? AND tenant_id = ? AND status = 'pending'"
        );
        $stmt->bind_param('isis', $staffId, $staffName, $taskId, $tenantId);
        $stmt->execute();
        $accepted = $stmt->affected_rows === 1;
        $stmt->close();
        if (!$accepted) {
            $currentStmt = $conn->prepare(
                'SELECT status, accepted_by_staff_id FROM waiter_ready_tasks
                 WHERE id = ? AND tenant_id = ? LIMIT 1'
            );
            $currentStmt->bind_param('is', $taskId, $tenantId);
            $currentStmt->execute();
            $current = $currentStmt->get_result()->fetch_assoc();
            $currentStmt->close();
            if ($current &&
                $current['status'] === 'accepted' &&
                (int)$current['accepted_by_staff_id'] === $staffId) {
                waiterReadyRespond(200, [
                    'status' => 'success',
                    'message' => 'You already accepted this service task',
                    'already_accepted' => true,
                ]);
            }
            waiterReadyRespond(409, [
                'status' => 'error',
                'message' => $current && $current['status'] === 'accepted'
                    ? 'Another waiter has already accepted this order'
                    : 'This service task is no longer available',
            ]);
        }
        waiterReadyRespond(200, [
            'status' => 'success',
            'message' => 'You accepted this order for serving',
        ]);
    }

    if ($action === 'complete' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        if ($staff['role'] !== 'waiter') {
            waiterReadyRespond(403, [
                'status' => 'error',
                'message' => 'Only waiters can complete service tasks',
            ]);
        }
        $input = waiterReadyInput();
        $taskId = filter_var($input['task_id'] ?? null, FILTER_VALIDATE_INT);
        if ($taskId === false || $taskId <= 0) {
            waiterReadyRespond(400, [
                'status' => 'error',
                'message' => 'A valid task_id is required',
            ]);
        }
        $stmt = $conn->prepare(
            "UPDATE waiter_ready_tasks task
             INNER JOIN orders order_row
                ON order_row.id = task.order_id
               AND order_row.tenant_id COLLATE utf8mb4_general_ci =
                   task.tenant_id COLLATE utf8mb4_general_ci
             SET task.status = 'completed',
                 task.completed_at = CURRENT_TIMESTAMP
             WHERE task.id = ? AND task.tenant_id = ?
               AND task.status = 'accepted'
               AND task.accepted_by_staff_id = ?
               AND LOWER(order_row.status) IN ('served', 'completed')"
        );
        $stmt->bind_param('isi', $taskId, $tenantId, $staffId);
        $stmt->execute();
        $completed = $stmt->affected_rows === 1;
        $stmt->close();
        if (!$completed) {
            waiterReadyRespond(409, [
                'status' => 'error',
                'message' => 'Mark the order served first, or confirm that you accepted it',
            ]);
        }
        waiterReadyRespond(200, [
            'status' => 'success',
            'message' => 'Service task completed',
        ]);
    }

    waiterReadyRespond(400, [
        'status' => 'error',
        'message' => 'Unknown waiter ready task action',
    ]);
} catch (Throwable $error) {
    error_log('Waiter ready API failed: ' . $error->getMessage());
    waiterReadyRespond(500, [
        'status' => 'error',
        'message' => 'Could not process waiter service task',
    ]);
}
?>
