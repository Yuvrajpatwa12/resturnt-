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

            if (empty($email) || empty($pin)) {
                echo json_encode(["status" => "error", "message" => "Missing email or PIN"]);
                break;
            }

            // Sync PIN globally for this customer email across all tenants
            $stmt = $conn->prepare("UPDATE customers SET pin = ? WHERE LOWER(email) = LOWER(?)");
            $stmt->bind_param("ss", $pin, $email);
            if ($stmt->execute()) {
                echo json_encode(["status" => "success"]);
            } else {
                echo json_encode(["status" => "error"]);
            }
            break;

        case 'verify_pin':
            $data = json_decode(file_get_contents('php://input'));
            $email = strtolower(trim($data->email ?? ''));
            $pin = trim($data->pin ?? '');

            if (empty($email) || empty($pin)) {
                echo json_encode(["status" => "error", "message" => "Missing email or PIN"]);
                break;
            }

            $stmt = $conn->prepare("SELECT email FROM customers WHERE LOWER(email) = LOWER(?) AND pin = ?");
            $stmt->bind_param("ss", $email, $pin);
            $stmt->execute();
            if ($stmt->get_result()->num_rows > 0) {
                echo json_encode(["status" => "success"]);
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

        default:
            echo json_encode(["status" => "error", "message" => "Invalid action"]);
            break;
    }
} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}

$conn->close();
?>
