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

function stockReportsRespond($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload);
    exit;
}

function stockReportsReadInput() {
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') return $_POST;
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        stockReportsRespond(400, [
            'status' => 'error',
            'message' => 'Invalid JSON payload',
        ]);
    }
    return $data;
}

try {
    $auth = requireAuth($conn, ['kitchen', 'waiter']);
    $staff = $auth['user'];
    $tenantId = trim((string)$staff['tenant_id']);
    if ($tenantId === '') {
        stockReportsRespond(401, [
            'status' => 'error',
            'message' => 'Authenticated staff tenant is missing',
        ]);
    }
    $role = strtolower(trim(str_replace([' ', '-'], '_', (string)$staff['role'])));
    $isAdmin = in_array($role, [
        'admin',
        'manager',
        'super_admin',
        'super_administrator',
    ], true);
    $action = (string)($_GET['action'] ?? $_POST['action'] ?? '');
    $input = $_SERVER['REQUEST_METHOD'] === 'POST'
        ? stockReportsReadInput()
        : [];
    $requestedTenant = trim((string)($input['tenant_id'] ??
        $_GET['tenant_id'] ?? $_POST['tenant_id'] ?? ''));
    if ($requestedTenant !== '' && $requestedTenant !== $tenantId) {
        stockReportsRespond(403, [
            'status' => 'error',
            'message' => 'Tenant does not match the authenticated staff session',
        ]);
    }

    $conn->query("CREATE TABLE IF NOT EXISTS stock_alerts (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(100) NOT NULL,
        ingredient_name VARCHAR(255) NOT NULL,
        current_quantity DECIMAL(10,2) NOT NULL DEFAULT 0,
        unit VARCHAR(50) DEFAULT NULL,
        alert_type VARCHAR(50) NOT NULL DEFAULT 'low_stock',
        status VARCHAR(50) NOT NULL DEFAULT 'Pending',
        requested_by VARCHAR(100) DEFAULT NULL,
        notes TEXT NULL,
        urgency VARCHAR(20) NOT NULL DEFAULT 'Medium',
        is_seen TINYINT(1) NOT NULL DEFAULT 0,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        resolved_at TIMESTAMP NULL DEFAULT NULL,
        INDEX idx_tenant_status (tenant_id, status),
        INDEX idx_alert_type (alert_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
    foreach ([
        'notes' => 'TEXT NULL',
        'urgency' => "VARCHAR(20) NOT NULL DEFAULT 'Medium'",
        'is_seen' => 'TINYINT(1) NOT NULL DEFAULT 0',
    ] as $column => $definition) {
        $columnCheck = $conn->query(
            "SHOW COLUMNS FROM stock_alerts LIKE '" .
            $conn->real_escape_string($column) . "'"
        );
        if ($columnCheck->num_rows === 0) {
            $conn->query("ALTER TABLE stock_alerts ADD COLUMN `$column` $definition");
        }
    }

    switch ($action) {
        case 'list':
            if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
                stockReportsRespond(405, [
                    'status' => 'error',
                    'message' => 'GET is required',
                ]);
            }
            $stmt = $conn->prepare(
                'SELECT id, tenant_id, ingredient_name AS item_name, notes, urgency,
                        status, requested_by AS reported_by, is_seen, created_at
                 FROM stock_alerts WHERE tenant_id = ?
                 ORDER BY created_at DESC, id DESC'
            );
            $stmt->bind_param('s', $tenantId);
            $stmt->execute();
            $reports = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            $stmt->close();
            stockReportsRespond(200, ['status' => 'success', 'data' => $reports]);

        case 'unseen_count':
            if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
                stockReportsRespond(405, [
                    'status' => 'error',
                    'message' => 'GET is required',
                ]);
            }
            $stmt = $conn->prepare(
                'SELECT COUNT(*) AS count FROM stock_alerts
                 WHERE tenant_id = ? AND is_seen = 0'
            );
            $stmt->bind_param('s', $tenantId);
            $stmt->execute();
            $count = (int)$stmt->get_result()->fetch_assoc()['count'];
            $stmt->close();
            stockReportsRespond(200, ['status' => 'success', 'count' => $count]);

        case 'mark_seen':
            if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !$isAdmin) {
                stockReportsRespond(403, [
                    'status' => 'error',
                    'message' => 'Only restaurant administrators can mark stock alerts as seen',
                ]);
            }
            $stmt = $conn->prepare(
                'UPDATE stock_alerts SET is_seen = 1
                 WHERE tenant_id = ? AND is_seen = 0'
            );
            $stmt->bind_param('s', $tenantId);
            $stmt->execute();
            $stmt->close();
            stockReportsRespond(200, ['status' => 'success', 'success' => true]);

        case 'create':
            if ($_SERVER['REQUEST_METHOD'] !== 'POST' ||
                !in_array($role, ['kitchen', 'admin', 'manager', 'super_admin', 'super_administrator'], true)) {
                stockReportsRespond(403, [
                    'status' => 'error',
                    'message' => 'Kitchen staff or a restaurant administrator is required',
                ]);
            }
            $itemName = trim((string)($input['item_name'] ?? ''));
            $notes = trim((string)($input['notes'] ?? ''));
            $urgency = trim((string)($input['urgency'] ?? 'Medium'));
            if ($itemName === '' || strlen($itemName) > 255 ||
                !in_array($urgency, ['Low', 'Medium', 'Critical'], true)) {
                stockReportsRespond(400, [
                    'status' => 'error',
                    'message' => 'Provide an item name and valid urgency',
                ]);
            }
            $reportedBy = trim((string)$staff['name']);
            $stmt = $conn->prepare(
                "INSERT INTO stock_alerts
                 (tenant_id, ingredient_name, notes, urgency, alert_type, status,
                  requested_by, is_seen)
                 VALUES (?, ?, ?, ?, 'stock_out', 'Requested', ?, 0)"
            );
            $stmt->bind_param(
                'sssss',
                $tenantId,
                $itemName,
                $notes,
                $urgency,
                $reportedBy
            );
            $stmt->execute();
            $reportId = (int)$conn->insert_id;
            $stmt->close();

            try {
                $adminRecipients = [];
                $tenantStmt = $conn->prepare(
                    'SELECT contact_email, primary_email FROM tenants
                     WHERE tenant_id = ? LIMIT 1'
                );
                $tenantStmt->bind_param('s', $tenantId);
                $tenantStmt->execute();
                $tenant = $tenantStmt->get_result()->fetch_assoc();
                $tenantStmt->close();
                if ($tenant) {
                    $adminRecipients[] = $tenant['contact_email'];
                    $adminRecipients[] = $tenant['primary_email'];
                }
                $usersStmt = $conn->prepare(
                    "SELECT email FROM users WHERE tenant_id = ?
                     AND LOWER(TRIM(role)) IN ('admin', 'manager')
                     AND email IS NOT NULL AND TRIM(email) <> ''"
                );
                $usersStmt->bind_param('s', $tenantId);
                $usersStmt->execute();
                foreach ($usersStmt->get_result()->fetch_all(MYSQLI_ASSOC) as $row) {
                    $adminRecipients[] = $row['email'];
                }
                $usersStmt->close();

                $title = "Stock Alert: $itemName";
                $message = "$reportedBy reported $itemName ($urgency urgency). $notes";
                foreach (array_unique(array_filter(array_map(
                    static fn($email) => strtolower(trim((string)$email)),
                    $adminRecipients
                ))) as $adminEmail) {
                    if (!filter_var($adminEmail, FILTER_VALIDATE_EMAIL)) continue;
                    $notification = $conn->prepare(
                        "INSERT INTO notifications
                         (tenant_id, user_id, title, message, type)
                         VALUES (?, ?, ?, ?, 'stock')"
                    );
                    $notification->bind_param(
                        'ssss',
                        $tenantId,
                        $adminEmail,
                        $title,
                        $message
                    );
                    $notification->execute();
                    $notificationId = (int)$conn->insert_id;
                    $notification->close();
                    queueEmailNotification(
                        $conn,
                        $tenantId,
                        $adminEmail,
                        $notificationId,
                        'stock'
                    );
                }
            } catch (Throwable $notificationError) {
                error_log(
                    "Stock report #$reportId was saved, but admin notification failed: " .
                    $notificationError->getMessage()
                );
            }
            stockReportsRespond(201, [
                'status' => 'success',
                'success' => true,
                'message' => 'Stock report sent to the restaurant administrators',
                'report_id' => $reportId,
            ]);

        case 'update_status':
            if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
                stockReportsRespond(405, [
                    'status' => 'error',
                    'message' => 'POST is required',
                ]);
            }
            $reportId = (int)($input['report_id'] ?? 0);
            $status = trim((string)($input['status'] ?? ''));
            if ($reportId <= 0 ||
                !in_array($status, ['Approved', 'Received'], true) ||
                (!$isAdmin && !(
                    in_array($role, ['kitchen', 'waiter'], true) &&
                    $status === 'Received'
                ))) {
                stockReportsRespond(403, [
                    'status' => 'error',
                    'message' => 'You cannot perform this stock report action',
                ]);
            }
            $conn->begin_transaction();
            $stmt = $conn->prepare(
                'SELECT status FROM stock_alerts
                 WHERE id = ? AND tenant_id = ? LIMIT 1 FOR UPDATE'
            );
            $stmt->bind_param('is', $reportId, $tenantId);
            $stmt->execute();
            $report = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            if (!$report) {
                $conn->rollback();
                stockReportsRespond(404, [
                    'status' => 'error',
                    'message' => 'Stock report was not found for this restaurant',
                ]);
            }
            $currentStatus = (string)$report['status'];
            $validTransition = ($isAdmin && $status === 'Approved' &&
                    in_array($currentStatus, ['Requested', 'Pending'], true)) ||
                ($status === 'Received' && $currentStatus === 'Approved');
            if (!$validTransition) {
                $conn->rollback();
                stockReportsRespond(409, [
                    'status' => 'error',
                    'message' => 'Stock report status has changed; refresh and retry',
                ]);
            }
            $stmt = $conn->prepare(
                "UPDATE stock_alerts SET status = ?, is_seen = 1,
                    resolved_at = IF(? = 'Received', CURRENT_TIMESTAMP, resolved_at)
                 WHERE id = ? AND tenant_id = ?"
            );
            $stmt->bind_param('ssis', $status, $status, $reportId, $tenantId);
            $stmt->execute();
            $stmt->close();
            $conn->commit();
            stockReportsRespond(200, [
                'status' => 'success',
                'success' => true,
                'message' => 'Stock report updated',
                'new_status' => $status,
            ]);

        default:
            stockReportsRespond(400, [
                'status' => 'error',
                'message' => 'Unknown stock report action',
            ]);
    }
} catch (Throwable $error) {
    error_log('Stock reports API failed: ' . $error->getMessage());
    stockReportsRespond(500, [
        'status' => 'error',
        'message' => 'Stock report request failed',
    ]);
}
?>
