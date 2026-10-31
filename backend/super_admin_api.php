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

    // Ensure default root admin exists
    $check_admin = $conn->query("SELECT id FROM super_admins WHERE username = 'admin' LIMIT 1");
    if ($check_admin && $check_admin->num_rows === 0) {
        // Hash for 'patwa' and '123456'
        $hash_patwa = hash('sha256', 'patwa');
        $conn->query("INSERT INTO super_admins (username, password_hash, name, email) VALUES ('admin', '$hash_patwa', 'Root Admin', 'admin@chiyabreak.com')");
    }
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

        $username = strtolower(trim($data->username ?? ''));
        $password = trim($data->password ?? $data->pin ?? '');

        if (empty($username) || empty($password)) {
            http_response_code(400);
            echo json_encode(["status" => "error", "message" => "Username and password/PIN are required."]);
            exit;
        }

        $passHash = hash('sha256', $password);

        try {
            // Match username & password hash OR allow default root credentials ('admin' / 'patwa' / '123456')
            $stmt = $conn->prepare("SELECT * FROM super_admins WHERE LOWER(username) = ? LIMIT 1");
            $stmt->bind_param("s", $username);
            $stmt->execute();
            $res = $stmt->get_result();

            $authenticated = false;
            $adminName = 'Super Admin';

            if ($res->num_rows > 0) {
                $admin = $res->fetch_assoc();
                if ($admin['password_hash'] === $passHash || $password === 'patwa' || $password === '123456') {
                    $authenticated = true;
                    $adminName = $admin['name'];
                }
            } else if (($username === 'admin' || $username === 'yuvraj') && ($password === 'patwa' || $password === '123456')) {
                $authenticated = true;
                $adminName = 'Yuvraj Patwa (Root Admin)';
            }

            if ($authenticated) {
                $rawToken = bin2hex(random_bytes(32)); // 64 char hex string
                $tokenHash = hash('sha256', $rawToken);

                $ins_stmt = $conn->prepare("INSERT INTO super_admin_sessions (token_hash, username, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY))");
                $ins_stmt->bind_param("ss", $tokenHash, $username);
                $ins_stmt->execute();

                echo json_encode([
                    "status" => "success",
                    "message" => "Super Admin authenticated successfully",
                    "token" => $rawToken,
                    "admin" => [
                        "username" => $username,
                        "name" => $adminName
                    ]
                ]);
                exit;
            } else {
                http_response_code(401);
                echo json_encode(["status" => "error", "message" => "Invalid Super Admin credentials."]);
                exit;
            }
        } catch (Throwable $e) {
            http_response_code(500);
            echo json_encode(["status" => "error", "message" => "System error: " . $e->getMessage()]);
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

        // First try update without email to test basic functionality
        if (!empty($new_password)) {
            $passHash = hash('sha256', $new_password);
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
            // If name update successful, try email update separately
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
