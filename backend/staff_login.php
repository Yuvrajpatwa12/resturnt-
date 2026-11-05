<?php
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
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
if (!isset($conn) || !($conn instanceof mysqli) || $conn->connect_error) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database connection failed']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);
$tenantId = is_array($data) ? trim((string)($data['tenant_id'] ?? '')) : '';
$email = is_array($data) ? strtolower(trim((string)($data['email'] ?? ''))) : '';
$pin = is_array($data) ? trim((string)($data['pin'] ?? '')) : '';
if ($tenantId === '' || strlen($tenantId) > 100 || $email === '' || $pin === '') {
    http_response_code(400);
    echo json_encode([
        'status' => 'error',
        'message' => 'Restaurant, email, and security PIN are required',
    ]);
    exit;
}

try {
    $stmt = $conn->prepare(
        'SELECT u.id, u.name, u.role, u.tenant_id, t.restaurant_name
         FROM users u
         JOIN tenants t
           ON t.tenant_id COLLATE utf8mb4_general_ci =
              u.tenant_id COLLATE utf8mb4_general_ci
         WHERE LOWER(u.email) = LOWER(?)
           AND u.login_pin = ?
           AND u.tenant_id COLLATE utf8mb4_general_ci =
               ? COLLATE utf8mb4_general_ci
         LIMIT 1'
    );
    $stmt->bind_param('sss', $email, $pin, $tenantId);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user) {
        http_response_code(401);
        echo json_encode([
            'status' => 'error',
            'message' => 'Wrong email address or security PIN for this restaurant',
        ]);
        exit;
    }

    $conn->query("CREATE TABLE IF NOT EXISTS staff_api_tokens (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        token_hash CHAR(64) NOT NULL UNIQUE,
        expires_at DATETIME NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_staff_api_tokens_user_expiry (user_id, expires_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    if (session_status() === PHP_SESSION_NONE) {
        ini_set('session.use_strict_mode', '1');
        session_set_cookie_params([
            'lifetime' => 0,
            'path' => '/',
            'secure' => true,
            'httponly' => true,
            'samesite' => 'Lax'
        ]);
        if (!session_start()) {
            throw new RuntimeException('Could not start staff session');
        }
    }
    if (!session_regenerate_id(true)) {
        throw new RuntimeException('Could not rotate staff session');
    }

    $_SESSION['staff'] = [
        'id' => (int)$user['id'],
        'name' => (string)$user['name'],
        'role' => strtolower(trim((string)$user['role'])),
        'tenant_id' => (string)$user['tenant_id']
    ];

    $apiToken = bin2hex(random_bytes(32));
    $tokenHash = hash('sha256', $apiToken);
    $tokenStmt = $conn->prepare(
        'INSERT INTO staff_api_tokens (user_id, token_hash, expires_at)
         VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY))'
    );
    $userId = (int)$user['id'];
    $tokenStmt->bind_param('is', $userId, $tokenHash);
    $tokenStmt->execute();
    $tokenStmt->close();

    echo json_encode([
        'status' => 'success',
        'message' => 'Welcome back, ' . $user['name'],
        'token' => $apiToken,
        'user' => [
            'id' => (int)$user['id'],
            'name' => $user['name'],
            'role' => $user['role'],
            'tenant_id' => $user['tenant_id'],
            'restaurant_name' => $user['restaurant_name']
        ]
    ]);
} catch (Throwable $error) {
    error_log('Staff login failed: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Staff login is temporarily unavailable']);
}
?>
