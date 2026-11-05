<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=UTF-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/staff_auth.php';

function paymentMethodsRespond($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload);
    exit;
}

function paymentMethodsInput() {
    $rawInput = file_get_contents('php://input');
    if ($rawInput === false || trim($rawInput) === '') {
        return $_POST;
    }

    $data = json_decode($rawInput, true);
    if (!is_array($data)) {
        paymentMethodsRespond(400, [
            'status' => 'error',
            'message' => 'Invalid JSON payload',
        ]);
    }
    return $data;
}

try {
    $auth = requireAuth($conn, ['admin', 'cashier']);
    $staff = $auth['user'];
    $tenantId = trim((string)$staff['tenant_id']);
    if ($tenantId === '') {
        paymentMethodsRespond(401, [
            'status' => 'error',
            'message' => 'Authenticated staff tenant is missing',
        ]);
    }

    $action = (string)($_GET['action'] ?? $_POST['action'] ?? '');
    $input = in_array($action, [
        'toggle_payment_method',
        'save_payment_method',
        'delete_payment_method',
    ], true) ? paymentMethodsInput() : [];
    $requestedTenant = trim((string)($input['tenant_id'] ??
        $_GET['tenant_id'] ?? $_POST['tenant_id'] ?? ''));
    if ($requestedTenant !== '' && $requestedTenant !== $tenantId) {
        paymentMethodsRespond(403, [
            'status' => 'error',
            'message' => 'Tenant does not match the authenticated staff session',
        ]);
    }

    $methodTable = $conn->query("SHOW TABLES LIKE 'payment_methods'");
    if ($methodTable->num_rows === 0) {
        $conn->query("CREATE TABLE payment_methods (
            id INT AUTO_INCREMENT PRIMARY KEY,
            tenant_id VARCHAR(100) NOT NULL,
            method_id VARCHAR(50) NOT NULL,
            name VARCHAR(100) NOT NULL,
            category VARCHAR(50) NOT NULL,
            type VARCHAR(100) NOT NULL DEFAULT '',
            account_holder_name VARCHAR(100) NOT NULL DEFAULT 'Main Account',
            account_number VARCHAR(100) NOT NULL DEFAULT '',
            bank_provider VARCHAR(100) NOT NULL DEFAULT '',
            qr_image_url TEXT,
            is_active TINYINT(1) NOT NULL DEFAULT 1,
            is_default TINYINT(1) NOT NULL DEFAULT 0,
            surcharge VARCHAR(20) NOT NULL DEFAULT '0%',
            min_limit VARCHAR(50) NOT NULL DEFAULT 'NPR 0',
            max_limit VARCHAR(50) NOT NULL DEFAULT 'No Limit',
            description TEXT,
            sort_order INT NOT NULL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY tenant_method (tenant_id, method_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
    }

    $existingColumns = [];
    $columnsResult = $conn->query('SHOW COLUMNS FROM payment_methods');
    while ($column = $columnsResult->fetch_assoc()) {
        $existingColumns[$column['Field']] = true;
    }
    foreach ([
        'account_holder_name' => "VARCHAR(100) NOT NULL DEFAULT 'Main Account'",
        'account_number' => "VARCHAR(100) NOT NULL DEFAULT ''",
        'bank_provider' => "VARCHAR(100) NOT NULL DEFAULT ''",
        'qr_image_url' => 'TEXT NULL',
    ] as $column => $definition) {
        if (!isset($existingColumns[$column])) {
            $conn->query(
                "ALTER TABLE payment_methods ADD COLUMN `$column` $definition"
            );
        }
    }

    switch ($action) {
        case 'get_payment_methods':
        case 'get_active_methods':
            if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
                paymentMethodsRespond(405, [
                    'status' => 'error',
                    'message' => 'GET is required',
                ]);
            }
            $activeOnly = $action === 'get_active_methods';
            $sql = 'SELECT * FROM payment_methods WHERE tenant_id = ?' .
                ($activeOnly ? ' AND is_active = 1' : '') .
                ' ORDER BY sort_order ASC, id ASC';
            $stmt = $conn->prepare($sql);
            $stmt->bind_param('s', $tenantId);
            $stmt->execute();
            $methods = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            $stmt->close();
            foreach ($methods as &$method) {
                $method['id'] = (int)$method['id'];
                $method['is_active'] = (bool)$method['is_active'];
                $method['is_default'] = (bool)$method['is_default'];
                $method['sort_order'] = (int)$method['sort_order'];
                if (empty($method['account_holder_name'])) {
                    $method['account_holder_name'] = 'Main Account';
                }
            }
            unset($method);
            paymentMethodsRespond(200, [
                'status' => 'success',
                'data' => $methods,
            ]);

        case 'toggle_payment_method':
            if ($_SERVER['REQUEST_METHOD'] !== 'POST' ||
                !in_array($staff['role'], ['admin', 'manager', 'super_admin', 'super_administrator'], true)) {
                paymentMethodsRespond(403, [
                    'status' => 'error',
                    'message' => 'Only restaurant administrators can change payment methods',
                ]);
            }
            $methodId = trim((string)($input['method_id'] ?? ''));
            if ($methodId === '') {
                paymentMethodsRespond(400, [
                    'status' => 'error',
                    'message' => 'Missing method_id',
                ]);
            }
            $isActive = !empty($input['is_active']) ? 1 : 0;
            $stmt = $conn->prepare(
                'UPDATE payment_methods SET is_active = ?
                 WHERE tenant_id = ? AND method_id = ?'
            );
            $stmt->bind_param('iss', $isActive, $tenantId, $methodId);
            $stmt->execute();
            $updated = $stmt->affected_rows;
            $stmt->close();
            $stmt = $conn->prepare(
                'SELECT 1 FROM payment_methods WHERE tenant_id = ? AND method_id = ? LIMIT 1'
            );
            $stmt->bind_param('ss', $tenantId, $methodId);
            $stmt->execute();
            $exists = $stmt->get_result()->num_rows > 0;
            $stmt->close();
            if (!$exists) {
                paymentMethodsRespond(404, [
                    'status' => 'error',
                    'message' => 'Payment method not found for this restaurant',
                ]);
            }
            paymentMethodsRespond(200, [
                'status' => 'success',
                'message' => 'Payment method status updated successfully',
                'method_id' => $methodId,
                'is_active' => (bool)$isActive,
                'affected_rows' => $updated,
            ]);

        case 'save_payment_method':
            if ($_SERVER['REQUEST_METHOD'] !== 'POST' ||
                !in_array($staff['role'], ['admin', 'manager', 'super_admin', 'super_administrator'], true)) {
                paymentMethodsRespond(403, [
                    'status' => 'error',
                    'message' => 'Only restaurant administrators can change payment methods',
                ]);
            }
            $methodId = trim((string)($input['method_id'] ?? ''));
            $name = trim((string)($input['name'] ?? 'Payment Method'));
            $category = trim((string)($input['category'] ?? 'QR'));
            if ($methodId === '' || strlen($methodId) > 50 || $name === '') {
                paymentMethodsRespond(400, [
                    'status' => 'error',
                    'message' => 'A valid method_id and name are required',
                ]);
            }
            $type = trim((string)($input['type'] ?? 'Custom Account'));
            $accountHolderName = trim((string)($input['account_holder_name'] ?? 'Main Account'));
            $accountNumber = trim((string)($input['account_number'] ?? ''));
            $bankProvider = trim((string)($input['bank_provider'] ?? ''));
            $qrImageUrl = trim((string)($input['qr_image_url'] ?? ''));
            $isActive = !empty($input['is_active']) ? 1 : 0;
            $isDefault = !empty($input['is_default']) ? 1 : 0;
            $surcharge = trim((string)($input['surcharge'] ?? '0%'));
            $minLimit = trim((string)($input['min_limit'] ?? 'NPR 0'));
            $maxLimit = trim((string)($input['max_limit'] ?? 'No Limit'));
            $description = trim((string)($input['description'] ?? ''));
            $stmt = $conn->prepare(
                'INSERT INTO payment_methods (
                    tenant_id, method_id, name, category, type,
                    account_holder_name, account_number, bank_provider, qr_image_url,
                    is_active, is_default, surcharge, min_limit, max_limit, description
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    name = VALUES(name),
                    category = VALUES(category),
                    type = VALUES(type),
                    account_holder_name = VALUES(account_holder_name),
                    account_number = VALUES(account_number),
                    bank_provider = VALUES(bank_provider),
                    qr_image_url = VALUES(qr_image_url),
                    is_active = VALUES(is_active),
                    is_default = VALUES(is_default),
                    surcharge = VALUES(surcharge),
                    min_limit = VALUES(min_limit),
                    max_limit = VALUES(max_limit),
                    description = VALUES(description)'
            );
            $stmt->bind_param(
                'sssssssss' . 'ii' . 'ssss',
                $tenantId,
                $methodId,
                $name,
                $category,
                $type,
                $accountHolderName,
                $accountNumber,
                $bankProvider,
                $qrImageUrl,
                $isActive,
                $isDefault,
                $surcharge,
                $minLimit,
                $maxLimit,
                $description
            );
            $stmt->execute();
            $stmt->close();
            paymentMethodsRespond(200, [
                'status' => 'success',
                'message' => 'Payment method saved successfully',
                'method_id' => $methodId,
                'account_holder_name' => $accountHolderName,
            ]);

        case 'delete_payment_method':
            if ($_SERVER['REQUEST_METHOD'] !== 'POST' ||
                !in_array($staff['role'], ['admin', 'manager', 'super_admin', 'super_administrator'], true)) {
                paymentMethodsRespond(403, [
                    'status' => 'error',
                    'message' => 'Only restaurant administrators can change payment methods',
                ]);
            }
            $methodId = trim((string)($input['method_id'] ?? ''));
            if ($methodId === '') {
                paymentMethodsRespond(400, [
                    'status' => 'error',
                    'message' => 'Missing method_id',
                ]);
            }
            $stmt = $conn->prepare(
                'DELETE FROM payment_methods WHERE tenant_id = ? AND method_id = ?'
            );
            $stmt->bind_param('ss', $tenantId, $methodId);
            $stmt->execute();
            $deleted = $stmt->affected_rows;
            $stmt->close();
            if ($deleted === 0) {
                paymentMethodsRespond(404, [
                    'status' => 'error',
                    'message' => 'Payment method not found for this restaurant',
                ]);
            }
            paymentMethodsRespond(200, [
                'status' => 'success',
                'message' => 'Payment method deleted successfully',
                'method_id' => $methodId,
            ]);

        default:
            paymentMethodsRespond(400, [
                'status' => 'error',
                'message' => 'Unknown action',
            ]);
    }
} catch (Throwable $error) {
    error_log('Payment methods API failed: ' . $error->getMessage());
    paymentMethodsRespond(500, [
        'status' => 'error',
        'message' => 'Payment method request failed',
    ]);
}
?>
