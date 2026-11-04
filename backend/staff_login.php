<?php
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

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
$email = is_array($data) ? strtolower(trim((string)($data['email'] ?? ''))) : '';
$pin = is_array($data) ? trim((string)($data['pin'] ?? '')) : '';
if ($email === '' || $pin === '') {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Email and security PIN are required']);
    exit;
}

try {
    $stmt = $conn->prepare(
        'SELECT u.id, u.name, u.role, u.tenant_id, t.restaurant_name
         FROM users u
         JOIN tenants t ON u.tenant_id = t.tenant_id
         WHERE LOWER(u.email) = LOWER(?) AND u.login_pin = ?
         LIMIT 1'
    );
    $stmt->bind_param('ss', $email, $pin);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user) {
        http_response_code(401);
        echo json_encode(['status' => 'error', 'message' => 'Wrong email address or security PIN']);
        exit;
    }

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

    echo json_encode([
        'status' => 'success',
        'message' => 'Welcome back, ' . $user['name'],
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
