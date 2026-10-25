<?php
/**
 * Customer Identity & Auth API
 * Handles automatic email syncing and PIN security.
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';
require_once 'email_notification_common.php';

$conn->query("CREATE TABLE IF NOT EXISTS user_privacy_settings (
    tenant_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(190) NOT NULL,
    is_public TINYINT(1) NOT NULL DEFAULT 1,
    allow_waves TINYINT(1) NOT NULL DEFAULT 1,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Database connection failed"]));
}

$action = $_GET['action'] ?? '';
$tenant_id = $_GET['tenant_id'] ?? '';

try {
    switch ($action) {
        case 'sync_profile':
            $data = json_decode(file_get_contents('php://input'));
            if (!$data || empty($data->email)) {
                echo json_encode(["status" => "error", "message" => "Email missing"]);
                exit;
            }

            $email = strtolower(trim($data->email));
            $name = trim($data->name ?? 'Diner');
            if (empty($name)) $name = 'Diner';

            // Check if customer exists in this shop
            $stmt = $conn->prepare("SELECT * FROM customers WHERE LOWER(email) = LOWER(?) AND tenant_id = ?");
            $stmt->bind_param("ss", $email, $tenant_id);
            $stmt->execute();
            $res = $stmt->get_result();

            if ($res->num_rows > 0) {
                $user = $res->fetch_assoc();
                $hasPin = !empty($user['pin']) && trim($user['pin']) !== '';
                echo json_encode([
                    "status" => "success",
                    "exists" => true,
                    "is_registered" => true,
                    "is_new_to_shop" => false,
                    "has_pin" => $hasPin,
                    "needs_pin" => !$hasPin,
                    "user" => $user
                ]);
            } else {
                // Not in this shop. Check if exists globally across any branch
                $global_stmt = $conn->prepare("SELECT name, pin FROM customers WHERE LOWER(email) = LOWER(?) AND pin IS NOT NULL AND pin != '' LIMIT 1");
                $global_stmt->bind_param("s", $email);
                $global_stmt->execute();
                $global_res = $global_stmt->get_result();

                $final_name = $name;
                $stored_pin = null;
                $isRegisteredGlobal = false;

                if ($global_res->num_rows > 0) {
                    $global_user = $global_res->fetch_assoc();
                    $final_name = !empty($global_user['name']) ? $global_user['name'] : $name;
                    $stored_pin = $global_user['pin'];
                    $isRegisteredGlobal = true;
                }

                $hasPin = !empty($stored_pin) && trim($stored_pin) !== '';

                // Auto-create customer entry for THIS shop
                $ins = $conn->prepare("INSERT INTO customers (email, tenant_id, name, pin) VALUES (?, ?, ?, ?)");
                $ins->bind_param("ssss", $email, $tenant_id, $final_name, $stored_pin);
                $ins->execute();

                echo json_encode([
                    "status" => "success",
                    "exists" => true,
                    "is_registered" => $isRegisteredGlobal || $hasPin,
                    "is_new_to_shop" => true,
                    "has_pin" => $hasPin,
                    "needs_pin" => !$hasPin,
                    "user" => ["email" => $email, "name" => $final_name, "points" => 0, "order_count" => 0]
                ]);
            }
            break;

        case 'save_pin':
            $data = json_decode(file_get_contents('php://input'));
            $email = strtolower(trim($data->email ?? ''));
            $pin = trim($data->pin ?? '');

            if (empty($email) || empty($pin) || empty($tenant_id)) {
                echo json_encode(["status" => "error", "message" => "Missing email or PIN"]);
                break;
            }

            $tenant_check = $conn->prepare("SELECT 1 FROM customers
                WHERE LOWER(email) = LOWER(?) AND tenant_id = ? LIMIT 1");
            $tenant_check->bind_param("ss", $email, $tenant_id);
            $tenant_check->execute();
            if ($tenant_check->get_result()->num_rows === 0) {
                echo json_encode(["status" => "error", "message" => "Customer profile not found"]);
                break;
            }

            // Sync PIN globally for this customer email across all tenants
            $stmt = $conn->prepare("UPDATE customers SET pin = ? WHERE LOWER(email) = LOWER(?)");
            $stmt->bind_param("ss", $pin, $email);
            if ($stmt->execute()) {
                echo json_encode([
                    "status" => "success",
                    "session_token" => issueCustomerSession($conn, $email, $tenant_id)
                ]);
            } else {
                echo json_encode(["status" => "error"]);
            }
            break;

        case 'verify_pin':
            $data = json_decode(file_get_contents('php://input'));
            $email = strtolower(trim($data->email ?? ''));
            $pin = trim($data->pin ?? '');

            if (empty($email) || empty($pin) || empty($tenant_id)) {
                echo json_encode(["status" => "error", "message" => "Missing email or PIN"]);
                break;
            }

            if (!preg_match('/^\d{4}$/', $pin)) {
                echo json_encode(["status" => "error", "message" => "PIN must contain exactly 4 digits"]);
                break;
            }

            $stmt = $conn->prepare("SELECT 1 FROM customers
                WHERE LOWER(TRIM(email)) = ? AND tenant_id = ?
                    AND LPAD(TRIM(CAST(pin AS CHAR)), 4, '0') = ?
                LIMIT 1");
            $stmt->bind_param("sss", $email, $tenant_id, $pin);
            $stmt->execute();
            if ($stmt->get_result()->num_rows > 0) {
                echo json_encode([
                    "status" => "success",
                    "session_token" => issueCustomerSession($conn, $email, $tenant_id)
                ]);
            } else {
                echo json_encode(["status" => "error", "message" => "Incorrect Security PIN"]);
            }
            break;

        case 'update_fcm':
            $data = json_decode(file_get_contents('php://input'));
            $uid = $data->user_id;
            $token = $data->fcm_token;

            $stmt = $conn->prepare("UPDATE customers SET fcm_token = ? WHERE email = ? AND tenant_id = ?");
            $stmt->bind_param("sss", $token, $uid, $tenant_id);
            if ($stmt->execute()) {
                echo json_encode(["status" => "success"]);
            } else {
                echo json_encode(["status" => "error"]);
            }
            break;

        case 'update_privacy':
            $data = json_decode(file_get_contents('php://input'));
            $uid = trim((string)($data->user_id ?? ''));
            if ($uid === '' || $tenant_id === '') {
                echo json_encode(["status" => "error", "message" => "Missing user or tenant"]);
                break;
            }

            $isPublic = !empty($data->is_public) ? 1 : 0;
            $allowWaves = !empty($data->allow_waves) ? 1 : 0;
            $stmt = $conn->prepare("INSERT INTO user_privacy_settings
                (tenant_id, user_id, is_public, allow_waves)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    is_public = VALUES(is_public),
                    allow_waves = VALUES(allow_waves)");
            if (!$stmt) throw new Exception("Could not prepare privacy update");
            $stmt->bind_param("ssii", $tenant_id, $uid, $isPublic, $allowWaves);
            if (!$stmt->execute()) throw new Exception("Could not save privacy settings");
            $stmt->close();
            echo json_encode(["status" => "success"]);
            break;

        default:
            echo json_encode(["status" => "error", "message" => "Invalid action"]);
            break;
    }
} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}

$conn->close();
?>
