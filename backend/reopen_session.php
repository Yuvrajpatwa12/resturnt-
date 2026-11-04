<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=UTF-8');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}
require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/staff_auth.php';
require_once __DIR__ . '/billing_common.php';

try {
    $auth = requireAuth($conn, ['admin', 'super_admin']);
    $staff = isset($auth['user']) && is_array($auth['user']) ? $auth['user'] : [];
    if (empty($staff['tenant_id'])) {
        billingRespond(401, ['status' => 'error', 'message' => 'Authenticated staff tenant is missing']);
    }
    billingEnsureSchema($conn);
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        billingRespond(405, ['status' => 'error', 'message' => 'POST is required']);
    }
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) {
        billingRespond(400, ['status' => 'error', 'message' => 'Invalid JSON request']);
    }
    $sessionId = (int)($data['session_id'] ?? 0);
    $tableId = (int)($data['table_id'] ?? 0);
    if (($sessionId > 0) === ($tableId > 0)) {
        billingRespond(400, ['status' => 'error', 'message' => 'Provide exactly one of session_id or table_id']);
    }
    $tenantId = (string)$staff['tenant_id'];
    $conn->begin_transaction();
    if ($sessionId > 0) {
        $probe = $conn->prepare(
            'SELECT table_id, table_number FROM dining_sessions
             WHERE id = ? AND tenant_id = ? LIMIT 1'
        );
        $probe->bind_param('is', $sessionId, $tenantId);
        $probe->execute();
        $location = $probe->get_result()->fetch_assoc();
        $probe->close();
        if (!$location) {
            $conn->rollback();
            billingRespond(404, ['status' => 'error', 'message' => 'No dining session was found for this table']);
        }
        if (!empty($location['table_id'])) {
            $tableLock = $conn->prepare(
                'SELECT id FROM restaurant_tables WHERE id = ? AND tenant_id = ? FOR UPDATE'
            );
            $locationTableId = (int)$location['table_id'];
            $tableLock->bind_param('is', $locationTableId, $tenantId);
        } else {
            $tableLock = $conn->prepare(
                'SELECT id FROM restaurant_tables WHERE table_number = ? AND tenant_id = ? FOR UPDATE'
            );
            $locationTableNumber = (int)$location['table_number'];
            $tableLock->bind_param('is', $locationTableNumber, $tenantId);
        }
        $tableLock->execute();
        $lockedTable = $tableLock->get_result()->fetch_assoc();
        $tableLock->close();
        if (!$lockedTable) {
            $conn->rollback();
            billingRespond(404, ['status' => 'error', 'message' => 'Restaurant table was not found']);
        }
        $sessionLookup = $conn->prepare(
            'SELECT id, table_id, table_number, status FROM dining_sessions
             WHERE id = ? AND tenant_id = ? LIMIT 1 FOR UPDATE'
        );
        $sessionLookup->bind_param('is', $sessionId, $tenantId);
    } else {
        $tableLock = $conn->prepare(
            'SELECT id, table_number FROM restaurant_tables
             WHERE id = ? AND tenant_id = ? LIMIT 1 FOR UPDATE'
        );
        $tableLock->bind_param('is', $tableId, $tenantId);
        $tableLock->execute();
        $tableLocation = $tableLock->get_result()->fetch_assoc();
        $tableLock->close();
        if (!$tableLocation) {
            $conn->rollback();
            billingRespond(404, ['status' => 'error', 'message' => 'Restaurant table was not found']);
        }
        $tableNumber = (int)$tableLocation['table_number'];
        $sessionLookup = $conn->prepare(
            "SELECT id, table_id, table_number, status FROM dining_sessions
             WHERE tenant_id = ? AND (table_id = ? OR
                 (table_id IS NULL AND table_number = ?))
             ORDER BY id DESC LIMIT 1 FOR UPDATE"
        );
        $sessionLookup->bind_param('sii', $tenantId, $tableId, $tableNumber);
    }
    $sessionLookup->execute();
    $session = $sessionLookup->get_result()->fetch_assoc();
    $sessionLookup->close();
    if (!$session) {
        $conn->rollback();
        billingRespond(404, ['status' => 'error', 'message' => 'No dining session was found for this table']);
    }
    if (!in_array(strtolower((string)$session['status']), ['settled', 'closed'], true)) {
        $conn->rollback();
        billingRespond(409, ['status' => 'error', 'message' => 'Only settled or closed sessions can be reopened']);
    }
    $otherActiveStmt = $conn->prepare(
        "SELECT COUNT(*) AS active_count FROM dining_sessions
         WHERE tenant_id = ? AND id <> ? AND
           (table_id = ? OR table_number = ?)
           AND LOWER(status) NOT IN ('settled', 'closed')"
    );
    $resolvedSessionId = (int)$session['id'];
    $resolvedTableId = (int)($session['table_id'] ?? $tableId);
    $resolvedTableNumber = (int)$session['table_number'];
    $otherActiveStmt->bind_param(
        'siii',
        $tenantId,
        $resolvedSessionId,
        $resolvedTableId,
        $resolvedTableNumber
    );
    $otherActiveStmt->execute();
    $hasOtherActiveSession = (int)$otherActiveStmt->get_result()
        ->fetch_assoc()['active_count'] > 0;
    $otherActiveStmt->close();
    if ($hasOtherActiveSession) {
        $conn->rollback();
        billingRespond(409, ['status' => 'error', 'message' => 'Another active session already exists for this table']);
    }
    $update = $conn->prepare("UPDATE dining_sessions SET status = 'Open', last_modified = CURRENT_TIMESTAMP
        WHERE id = ? AND tenant_id = ?");
    $update->bind_param('is', $resolvedSessionId, $tenantId);
    $update->execute();
    $update->close();
    if (!empty($session['table_id'])) {
        $tableUpdate = $conn->prepare("UPDATE restaurant_tables SET status = 'Dining' WHERE id = ? AND tenant_id = ?");
        $sessionTableId = (int)$session['table_id'];
        $tableUpdate->bind_param('is', $sessionTableId, $tenantId);
    } else {
        $tableUpdate = $conn->prepare("UPDATE restaurant_tables SET status = 'Dining' WHERE table_number = ? AND tenant_id = ?");
        $tableNumber = (int)$session['table_number'];
        $tableUpdate->bind_param('is', $tableNumber, $tenantId);
    }
    $tableUpdate->execute();
    $tableUpdate->close();
    $conn->commit();
    billingRespond(200, ['status' => 'success', 'session_id' => $resolvedSessionId, 'session_status' => 'Open']);
} catch (Throwable $error) {
    try { $conn->rollback(); } catch (Throwable $ignored) {}
    error_log('Session reopen failed: ' . $error->getMessage());
    billingRespond(500, ['status' => 'error', 'message' => 'Could not reopen this table session']);
}
?>
