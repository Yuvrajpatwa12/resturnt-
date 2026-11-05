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
require_once __DIR__ . '/super_admin_api.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(['success' => false, 'status' => 'error', 'message' => 'POST method is required']);
        exit;
    }

    if (!verifySuperAdminSession($conn)) {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'status' => 'error',
            'message' => 'Super administrator authentication is required',
        ]);
        exit;
    }

    $rawInput = file_get_contents('php://input');
    $data = json_decode($rawInput, true);

    if (!is_array($data)) {
        echo json_encode(['success' => false, 'status' => 'error', 'message' => 'Invalid JSON input']);
        exit;
    }

    $tenantId = trim((string)($data['tenant_id'] ?? ''));
    $email = trim((string)($data['email'] ?? ''));
    $pin = trim((string)($data['pin'] ?? ''));

    if (empty($tenantId) || empty($email) || empty($pin)) {
        echo json_encode(['success' => false, 'status' => 'error', 'message' => 'Tenant ID, Email, and PIN are required']);
        exit;
    }

    // 1. Update tenants table contact email
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS contact_email VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS primary_email VARCHAR(255) DEFAULT ''");

    $tStmt = $conn->prepare("UPDATE tenants SET contact_email = ?, primary_email = ? WHERE tenant_id = ? OR domain = ? OR custom_domain = ?");
    $tStmt->bind_param("sssss", $email, $email, $tenantId, $tenantId, $tenantId);
    $tStmt->execute();
    $tStmt->close();

    // 2. Ensure users table exists and all pin/password columns exist
    @$conn->query("CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(50) NOT NULL,
        name VARCHAR(255) DEFAULT 'Admin',
        email VARCHAR(255) NOT NULL,
        pin VARCHAR(255) DEFAULT '',
        login_pin VARCHAR(255) DEFAULT '',
        password VARCHAR(255) DEFAULT '',
        password_hash VARCHAR(255) DEFAULT '',
        role VARCHAR(50) DEFAULT 'Admin',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    @$conn->query("ALTER TABLE users ADD COLUMN IF NOT EXISTS pin VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE users ADD COLUMN IF NOT EXISTS login_pin VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE users ADD COLUMN IF NOT EXISTS password VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255) DEFAULT ''");

    // Check if an admin user already exists for this tenant
    $uCheck = $conn->prepare("SELECT id FROM users WHERE tenant_id = ? AND (role LIKE '%admin%' OR role LIKE '%super%') LIMIT 1");
    $uCheck->bind_param("s", $tenantId);
    $uCheck->execute();
    $uRes = $uCheck->get_result();
    $uCheck->close();

    $hashedPin = password_hash($pin, PASSWORD_DEFAULT);

    if ($uRes->num_rows > 0) {
        $uUpd = $conn->prepare("UPDATE users SET email = ?, pin = ?, login_pin = ?, password = ?, password_hash = ? WHERE tenant_id = ? AND (role LIKE '%admin%' OR role LIKE '%super%')");
        $uUpd->bind_param("ssssss", $email, $pin, $pin, $hashedPin, $hashedPin, $tenantId);
        $uUpd->execute();
        $uUpd->close();
    } else {
        $uIns = $conn->prepare("INSERT INTO users (tenant_id, name, email, pin, login_pin, password, password_hash, role) VALUES (?, 'Restaurant Admin', ?, ?, ?, ?, ?, 'Admin')");
        $uIns->bind_param("ssssss", $tenantId, $email, $pin, $pin, $hashedPin, $hashedPin);
        $uIns->execute();
        $uIns->close();
    }

    echo json_encode([
        'success' => true,
        'status' => 'success',
        'message' => 'Admin credentials and login PIN updated successfully!'
    ]);

} catch (Throwable $e) {
    error_log("Update Tenant Credentials Error: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'status' => 'error',
        'message' => 'Failed to update tenant credentials'
    ]);
}
?>
