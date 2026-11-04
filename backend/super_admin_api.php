<?php
/**
 * super_admin_api.php - Super Admin Authentication & Session Management
 */

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';

// Auto-run schema setup if needed
try {
    @$conn->query("CREATE TABLE IF NOT EXISTS super_admins (
        id INT AUTO_INCREMENT PRIMARY KEY,
        username VARCHAR(100) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        name VARCHAR(100) NOT NULL DEFAULT 'Super Admin',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    @$conn->query("CREATE TABLE IF NOT EXISTS super_admin_sessions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        token_hash VARCHAR(64) NOT NULL UNIQUE,
        username VARCHAR(100) NOT NULL,
        expires_at DATETIME NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    @$conn->query("ALTER TABLE super_admins ADD COLUMN IF NOT EXISTS email VARCHAR(255) DEFAULT ''");

} catch (Throwable $e) {}

/**
 * Validates Super Admin Bearer Token from HTTP Authorization Header.
 * Returns array with admin info if valid, or null if unauthenticated.
 */
function verifySuperAdminSession($conn) {
    $authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if (empty($authorization) && function_exists('getallheaders')) {
        $headers = getallheaders();
        $authorization = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    }

    if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim($authorization), $matches)) {
        return null;
    }

    $rawToken = $matches[1];
    $tokenHash = hash('sha256', $rawToken);

    try {
        $stmt = $conn->prepare("SELECT s.username, a.name, a.email
                                FROM super_admin_sessions s
                                LEFT JOIN super_admins a ON a.username = s.username
                                WHERE s.token_hash = ? AND s.expires_at > NOW()
                                LIMIT 1");
        if (!$stmt) return null;
        $stmt->bind_param("s", $tokenHash);
        $stmt->execute();
        $res = $stmt->get_result();
        if ($row = $res->fetch_assoc()) {
            return [
                "username" => $row['username'],
                "name" => $row['name'] ?? $row['username'],
                "email" => $row['email'] ?? ''
            ];
        }
    } catch (Throwable $e) {}

    return null;
}

if (realpath($_SERVER['SCRIPT_FILENAME']) === __FILE__) {
    $action = $_GET['action'] ?? '';

    if ($action === 'login') {
        $json = file_get_contents('php://input');
        $data = json_decode($json);

        $email = strtolower(trim((string)($data->email ?? '')));
        $pin = trim((string)($data->pin ?? ''));

        if (!filter_var($email, FILTER_VALIDATE_EMAIL) ||
            strlen($email) > 255 ||
            strlen($pin) < 4 ||
            strlen($pin) > 64) {
            http_response_code(400);
            echo json_encode(["status" => "error", "message" => "Enter a valid email address and a PIN of 4 to 64 characters."]);
            exit;
        }

        try {
            $stmt = $conn->prepare(
                "SELECT id, username, email, name, password_hash
                 FROM super_admins WHERE LOWER(email) = ? LIMIT 2"
            );
            $stmt->bind_param("s", $email);
            $stmt->execute();
            $res = $stmt->get_result();
            if ($res->num_rows !== 1) {
                http_response_code(401);
                echo json_encode(["status" => "error", "message" => "Invalid email or PIN."]);
                exit;
            }
            $admin = $res->fetch_assoc();
            $storedHash = (string)$admin['password_hash'];
            $legacyHash = hash('sha256', $pin);
            $knownDemoHashes = [
                hash('sha256', 'patwa'),
                hash('sha256', '123456'),
                hash('sha256', 'admin')
            ];
            if (in_array($storedHash, $knownDemoHashes, true)) {
                http_response_code(401);
                echo json_encode(["status" => "error", "message" => "This account still uses a demo PIN. Set a new PIN in the database before signing in."]);
                exit;
            }
            $passwordMatches = password_verify($pin, $storedHash) ||
                hash_equals($storedHash, $legacyHash);
            if (!$passwordMatches) {
                http_response_code(401);
                echo json_encode(["status" => "error", "message" => "Invalid email or PIN."]);
                exit;
            }

            if (hash_equals($storedHash, $legacyHash)) {
                $upgradedHash = password_hash($pin, PASSWORD_DEFAULT);
                $upgrade = $conn->prepare(
                    'UPDATE super_admins SET password_hash = ? WHERE id = ?'
                );
                $upgrade->bind_param("si", $upgradedHash, $admin['id']);
                $upgrade->execute();
                $upgrade->close();
            }

            $rawToken = bin2hex(random_bytes(32));
            $tokenHash = hash('sha256', $rawToken);
            $username = (string)$admin['username'];
            $ins_stmt = $conn->prepare(
                "INSERT INTO super_admin_sessions (token_hash, username, expires_at)
                 VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY))"
            );
            $ins_stmt->bind_param("ss", $tokenHash, $username);
            $ins_stmt->execute();

            echo json_encode([
                "status" => "success",
                "message" => "Super Admin authenticated successfully",
                "token" => $rawToken,
                "admin" => [
                    "username" => $username,
                    "name" => (string)$admin['name'],
                    "email" => (string)$admin['email']
                ]
            ]);
            exit;
        } catch (Throwable $e) {
            error_log('Super Admin login failed: ' . $e->getMessage());
            http_response_code(500);
            echo json_encode(["status" => "error", "message" => "Could not authenticate Super Admin."]);
            exit;
        }
    } else if ($action === 'verify_session') {
        $admin = verifySuperAdminSession($conn);
        if ($admin) {
            echo json_encode(["status" => "success", "admin" => $admin]);
        } else {
            http_response_code(401);
            echo json_encode(["status" => "error", "message" => "Unauthenticated or session expired."]);
        }
        exit;
    } else if ($action === 'get_profile') {
        $admin = verifySuperAdminSession($conn);
        if (!$admin) {
            http_response_code(401);
            echo json_encode(["status" => "error", "message" => "Unauthorized"]);
            exit;
        }
        $stmt = $conn->prepare("SELECT username, name, email FROM super_admins WHERE username = ? LIMIT 1");
        $stmt->bind_param("s", $admin['username']);
        $stmt->execute();
        $res = $stmt->get_result();
        if ($row = $res->fetch_assoc()) {
            echo json_encode(["status" => "success", "profile" => $row]);
        } else {
            echo json_encode(["status" => "error", "message" => "Admin not found"]);
        }
        exit;
    } else if ($action === 'update_profile') {
        $admin = verifySuperAdminSession($conn);
        if (!$admin) {
            http_response_code(401);
            echo json_encode(["status" => "error", "message" => "Unauthorized"]);
            exit;
        }
        $json = file_get_contents('php://input');
        $data = json_decode($json);
        $email = trim((string)($data->email ?? ''));
        $name = trim((string)($data->name ?? ''));
        $new_password = trim((string)($data->new_password ?? ''));
        if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            http_response_code(400);
            echo json_encode(["status" => "error", "message" => "Enter a valid email address."]);
            exit;
        }
        if ($new_password !== '' && (strlen($new_password) < 4 || strlen($new_password) > 64)) {
            http_response_code(400);
            echo json_encode(["status" => "error", "message" => "PIN must be between 4 and 64 characters."]);
            exit;
        }
        if ($new_password !== '' &&
            in_array($new_password, ['patwa', '123456', 'admin'], true)) {
            http_response_code(400);
            echo json_encode(["status" => "error", "message" => "Choose a PIN other than the demo PIN."]);
            exit;
        }

        if ($email !== '') {
            $duplicate = $conn->prepare(
                'SELECT COUNT(*) AS email_count FROM super_admins
                 WHERE LOWER(email) = LOWER(?) AND username <> ?'
            );
            $duplicate->bind_param('ss', $email, $admin['username']);
            $duplicate->execute();
            $emailCount = (int)$duplicate->get_result()->fetch_assoc()['email_count'];
            $duplicate->close();
            if ($emailCount > 0) {
                http_response_code(409);
                echo json_encode(["status" => "error", "message" => "That email is already assigned to another Super Admin."]);
                exit;
            }
        }

        if (!empty($new_password)) {
            $passHash = password_hash($new_password, PASSWORD_DEFAULT);
            $stmt = $conn->prepare("UPDATE super_admins SET name = COALESCE(NULLIF(?, ''), name), password_hash = ? WHERE username = ?");
            if (!$stmt) {
                echo json_encode(["status" => "error", "message" => "DB Error: " . $conn->error]);
                exit;
            }
            $stmt->bind_param("sss", $name, $passHash, $admin['username']);
        } else {
            $stmt = $conn->prepare("UPDATE super_admins SET name = COALESCE(NULLIF(?, ''), name) WHERE username = ?");
            if (!$stmt) {
                echo json_encode(["status" => "error", "message" => "DB Error: " . $conn->error]);
                exit;
            }
            $stmt->bind_param("ss", $name, $admin['username']);
        }

        if ($stmt->execute()) {
            if (!empty($email)) {
                $check_column = $conn->query("SHOW COLUMNS FROM super_admins LIKE 'email'");
                if ($check_column && $check_column->num_rows > 0) {
                    $email_stmt = $conn->prepare("UPDATE super_admins SET email = ? WHERE username = ?");
                    if ($email_stmt) {
                        $email_stmt->bind_param("ss", $email, $admin['username']);
                        $email_stmt->execute();
                    }
                } else {
                    // Add email column
                    $conn->query("ALTER TABLE super_admins ADD COLUMN email VARCHAR(255) DEFAULT ''");
                    $email_stmt = $conn->prepare("UPDATE super_admins SET email = ? WHERE username = ?");
                    if ($email_stmt) {
                        $email_stmt->bind_param("ss", $email, $admin['username']);
                        $email_stmt->execute();
                    }
                }
            }
            echo json_encode(["status" => "success", "message" => "Admin profile updated successfully."]);
        } else {
            echo json_encode(["status" => "error", "message" => "Update failed: " . $stmt->error]);
        }
        exit;
    } else if ($_SERVER['REQUEST_METHOD'] !== 'OPTIONS') {
        echo json_encode(["status" => "error", "message" => "Invalid action"]);
    }
}
?>
