<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'GET is required']);
    exit;
}

require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/staff_auth.php';

try {
    $requestedTenantId = trim((string)($_GET['tenant_id'] ?? ''));
    if ($requestedTenantId === '' || strlen($requestedTenantId) > 100) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'A valid tenant_id is required']);
        exit;
    }

    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $authorization = (string)($headers['Authorization'] ??
        $headers['authorization'] ??
        $_SERVER['HTTP_AUTHORIZATION'] ??
        '');
    $hasStaffSession = session_status() === PHP_SESSION_ACTIVE &&
        isset($_SESSION['staff']) && is_array($_SESSION['staff']);
    $hasSessionCookie = isset($_COOKIE[session_name()]);
    if (!$hasStaffSession && $hasSessionCookie && session_status() === PHP_SESSION_NONE) {
        ini_set('session.use_strict_mode', '1');
        session_set_cookie_params([
            'lifetime' => 0,
            'path' => '/',
            'secure' => true,
            'httponly' => true,
            'samesite' => 'Lax'
        ]);
        if (session_start()) {
            $hasStaffSession = isset($_SESSION['staff']) && is_array($_SESSION['staff']);
        }
    }
    $staff = null;
    if (trim($authorization) !== '' || $hasStaffSession) {
        $auth = requireAuth($conn);
        $staff = isset($auth['user']) && is_array($auth['user']) ? $auth['user'] : [];
    }

    $tenantId = $requestedTenantId;
    if ($staff !== null) {
        $tenantId = trim((string)($staff['tenant_id'] ?? ''));
        if ($tenantId === '') {
            staffAuthRespond(401, 'Authenticated staff tenant is missing');
        }
        if ($requestedTenantId !== $tenantId) {
            staffAuthRespond(403, 'Tenant does not match the authenticated staff session');
        }
    }

    $activeTenant = $conn->prepare(
        'SELECT tenant_id FROM tenants
         WHERE tenant_id COLLATE utf8mb4_general_ci =
               ? COLLATE utf8mb4_general_ci
           AND is_active = 1
         LIMIT 1'
    );
    $activeTenant->bind_param('s', $tenantId);
    $activeTenant->execute();
    $tenantExists = $activeTenant->get_result()->fetch_assoc();
    $activeTenant->close();
    if (!$tenantExists) {
        http_response_code(404);
        echo json_encode(['status' => 'error', 'message' => 'Active restaurant tenant was not found']);
        exit;
    }

    if ($staff === null) {
        $stmt = $conn->prepare(
            "SELECT t.id, t.table_number,
                    COALESCE(NULLIF(t.status, ''), 'Available') AS status
             FROM restaurant_tables t
             WHERE t.tenant_id COLLATE utf8mb4_general_ci =
                   ? COLLATE utf8mb4_general_ci
             ORDER BY t.table_number, t.id"
        );
        $stmt->bind_param('s', $tenantId);
        $stmt->execute();
        $tables = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();
        echo json_encode(['status' => 'success', 'data' => $tables]);
        exit;
    }

    $stmt = $conn->prepare(
        "SELECT t.*,
            CASE
                WHEN EXISTS (
                    SELECT 1 FROM dining_sessions rs
                    WHERE rs.tenant_id COLLATE utf8mb4_general_ci =
                          t.tenant_id COLLATE utf8mb4_general_ci
                      AND (rs.table_id = t.id OR
                          (rs.table_id IS NULL AND rs.table_number = t.table_number))
                      AND LOWER(rs.status) = 'readyforbilling'
                ) THEN 'ReadyForBilling'
                WHEN EXISTS (
                    SELECT 1 FROM dining_sessions os
                    WHERE os.tenant_id COLLATE utf8mb4_general_ci =
                          t.tenant_id COLLATE utf8mb4_general_ci
                      AND (os.table_id = t.id OR
                          (os.table_id IS NULL AND os.table_number = t.table_number))
                      AND LOWER(os.status) NOT IN ('settled', 'closed')
                ) THEN 'Dining'
                WHEN LOWER(COALESCE(t.status, '')) IN ('reserved', 'dirty', 'maintenance')
                    THEN t.status
                ELSE 'Available'
            END AS lifecycle_status,
            (
                SELECT MAX(asess.id)
                FROM dining_sessions asess
                WHERE asess.tenant_id = t.tenant_id
                  AND (asess.table_id = t.id OR
                      (asess.table_id IS NULL AND asess.table_number = t.table_number))
                  AND LOWER(asess.status) NOT IN ('settled', 'closed')
            ) AS active_session_id
         FROM restaurant_tables t
         WHERE t.tenant_id COLLATE utf8mb4_general_ci =
               ? COLLATE utf8mb4_general_ci
         ORDER BY t.table_number, t.id"
    );
    $stmt->bind_param('s', $tenantId);
    $stmt->execute();
    $result = $stmt->get_result();
    $tables = [];
    while ($table = $result->fetch_assoc()) {
        $table['lifecycle_status'] = (string)$table['lifecycle_status'];
        $table['session_id'] = $table['active_session_id'] === null
            ? null
            : (int)$table['active_session_id'];
        unset($table['active_session_id']);
        $tables[] = $table;
    }
    $stmt->close();
    echo json_encode(['status' => 'success', 'data' => $tables]);
} catch (Throwable $error) {
    error_log('Table list lookup failed: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Could not load restaurant tables']);
}
?>
