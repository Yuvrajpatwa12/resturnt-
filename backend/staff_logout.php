
<?php
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
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
if (isset($conn) && $conn instanceof mysqli) {
    $headers = function_exists('getallheaders') ? getallheaders() : [];
    $authorization = (string)($headers['Authorization'] ??
        $headers['authorization'] ??
        $_SERVER['HTTP_AUTHORIZATION'] ??
        '');
    if (preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim($authorization), $matches)) {
        $tokenHash = hash('sha256', strtolower($matches[1]));
        $stmt = $conn->prepare('DELETE FROM staff_api_tokens WHERE token_hash = ?');
        $stmt->bind_param('s', $tokenHash);
        $stmt->execute();
        $stmt->close();
    }
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
    session_start();
}

$_SESSION = [];
if (ini_get('session.use_cookies')) {
    $params = session_get_cookie_params();
    $cookieOptions = [
        'expires' => time() - 42000,
        'path' => $params['path'],
        'secure' => $params['secure'],
        'httponly' => $params['httponly'],
        'samesite' => $params['samesite'] ?? 'Lax'
    ];
    if (!empty($params['domain'])) {
        $cookieOptions['domain'] = $params['domain'];
    }
    setcookie(session_name(), '', $cookieOptions);
}
session_destroy();
echo json_encode(['status' => 'success', 'message' => 'Staff session ended']);
?>
