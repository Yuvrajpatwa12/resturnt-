<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'POST is required']);
    exit;
}

require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/staff_auth.php';

try {
    $auth = requireAuth($conn, ['admin', 'manager']);
    $staff = isset($auth['user']) && is_array($auth['user']) ? $auth['user'] : [];
    $role = strtolower(trim(str_replace([' ', '-'], '_', (string)($staff['role'] ?? ''))));
    if (!in_array($role, ['admin', 'manager', 'super_admin', 'super_administrator'], true)) {
        staffAuthRespond(403, 'Your staff role cannot add restaurant tables');
    }

    $authenticatedTenantId = trim((string)($staff['tenant_id'] ?? ''));
    if ($authenticatedTenantId === '' || strlen($authenticatedTenantId) > 100) {
        staffAuthRespond(401, 'Authenticated staff tenant is missing');
    }

    $data = json_decode(file_get_contents('php://input'), true);
    $requestedTenantId = is_array($data)
        ? trim((string)($data['tenant_id'] ?? ''))
        : '';
    $tableNumber = is_array($data)
        ? filter_var($data['table_number'] ?? null, FILTER_VALIDATE_INT)
        : false;

    if (($requestedTenantId !== '' && $requestedTenantId !== $authenticatedTenantId) ||
        $tableNumber === false || $tableNumber < 1) {
        if ($requestedTenantId !== '' && $requestedTenantId !== $authenticatedTenantId) {
            staffAuthRespond(403, 'Tenant does not match the authenticated staff session');
        }
        http_response_code(400);
        echo json_encode([
            'status' => 'error',
            'message' => 'Provide a positive table_number',
        ]);
        exit;
    }
    $tenantId = $authenticatedTenantId;

    $tenant = $conn->prepare(
        'SELECT tenant_id FROM tenants
         WHERE tenant_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci
         LIMIT 1'
    );
    $tenant->bind_param('s', $tenantId);
    $tenant->execute();
    $tenantExists = $tenant->get_result()->fetch_assoc();
    $tenant->close();

    if (!$tenantExists) {
        http_response_code(404);
        echo json_encode(['status' => 'error', 'message' => 'Restaurant tenant was not found']);
        exit;
    }

    $duplicate = $conn->prepare(
        'SELECT id FROM restaurant_tables
         WHERE tenant_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci
           AND table_number = ?
         LIMIT 1'
    );
    $duplicate->bind_param('si', $tenantId, $tableNumber);
    $duplicate->execute();
    $alreadyExists = $duplicate->get_result()->fetch_assoc();
    $duplicate->close();

    if ($alreadyExists) {
        http_response_code(409);
        echo json_encode(['status' => 'error', 'message' => 'That table number already exists']);
        exit;
    }

    $insert = $conn->prepare(
        "INSERT INTO restaurant_tables (tenant_id, table_number, status)
         VALUES (?, ?, 'Available')"
    );
    $insert->bind_param('si', $tenantId, $tableNumber);
    $insert->execute();
    $tableId = (int)$conn->insert_id;
    $insert->close();

    echo json_encode([
        'status' => 'success',
        'message' => 'Table added successfully',
        'data' => [
            'id' => $tableId,
            'tenant_id' => $tenantId,
            'table_number' => $tableNumber,
            'status' => 'Available',
        ],
    ]);
} catch (Throwable $error) {
    error_log('Restaurant table creation failed: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Could not add restaurant table; check the restaurant_tables schema and server error log',
    ]);
}
?>
