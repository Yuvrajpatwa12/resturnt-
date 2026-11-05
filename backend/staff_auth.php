<?php
function staffAuthRespond($statusCode, $message) {
    http_response_code($statusCode);
    header('Content-Type: application/json; charset=UTF-8');
    echo json_encode([
        'status' => 'error',
        'message' => $message
    ]);
    exit;
}

if (!function_exists('requireAuth')) {
    function requireAuth($conn, $allowedRoles = []) {
        $headers = function_exists('getallheaders') ? getallheaders() : [];
        $authorization = (string)($headers['Authorization'] ??
            $headers['authorization'] ??
            $_SERVER['HTTP_AUTHORIZATION'] ??
            '');
        $staff = null;

        if (preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim($authorization), $matches)) {
            $tokenHash = hash('sha256', strtolower($matches[1]));
            $stmt = $conn->prepare(
                'SELECT u.id, u.name, u.role, u.tenant_id
                 FROM staff_api_tokens tok
                 JOIN users u ON u.id = tok.user_id
                 WHERE tok.token_hash = ? AND tok.expires_at > NOW()
                 LIMIT 1'
            );
            $stmt->bind_param('s', $tokenHash);
            $stmt->execute();
            $staff = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            if (!$staff) {
                staffAuthRespond(401, 'Staff authentication is required');
            }

            $staff['id'] = (int)$staff['id'];
            $staff['tenant_id'] = (string)$staff['tenant_id'];
        } else {
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
                    staffAuthRespond(500, 'Could not start staff session');
                }
            }

            $staff = isset($_SESSION['staff']) && is_array($_SESSION['staff'])
                ? $_SESSION['staff']
                : null;
        }

        if (!$staff ||
            empty($staff['id']) ||
            empty($staff['role']) ||
            empty($staff['tenant_id'])) {
            staffAuthRespond(401, 'Staff authentication is required');
        }

        if (!preg_match('/^Bearer\s+[a-f0-9]{64}$/i', trim($authorization))) {
            $staffId = (int)$staff['id'];
            $stmt = $conn->prepare(
                'SELECT role, tenant_id FROM users WHERE id = ? LIMIT 1'
            );
            $stmt->bind_param('i', $staffId);
            $stmt->execute();
            $currentUser = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            if (!$currentUser ||
                strtolower(trim((string)$currentUser['role'])) !== strtolower(trim((string)$staff['role'])) ||
                (string)$currentUser['tenant_id'] !== (string)$staff['tenant_id']) {
                $_SESSION = [];
                session_destroy();
                staffAuthRespond(401, 'Staff session is no longer valid');
            }
        }

        $rawRole = (string)($staff['role'] ?? '');
        $normalizedRole = strtolower(trim(str_replace([' ', '-'], '_', $rawRole)));
        $staff['role'] = $normalizedRole;

        if (!empty($allowedRoles)) {
            $normalizedAllowed = array_map(function($r) {
                return strtolower(trim(str_replace([' ', '-'], '_', $r)));
            }, $allowedRoles);

            $adminRoles = ['admin', 'super_admin', 'super_administrator', 'manager'];

            if (!in_array($normalizedRole, $adminRoles, true) && !in_array($normalizedRole, $normalizedAllowed, true)) {
                staffAuthRespond(403, 'Your staff role cannot perform this action');
            }
        }

        return ['user' => $staff];
    }
}
?>
