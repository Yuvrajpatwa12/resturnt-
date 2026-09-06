<?php
/**
 * Onboarding API (V2.1 - Robust Debugging)
 * Handles Name, Gender, and Anonymous status submission.
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';

$json = file_get_contents('php://input');
$data = json_decode($json);

// Log incoming request for debugging (Optional)
// file_put_contents('onboarding_log.txt', date('[Y-m-d H:i:s] ') . $json . PHP_EOL, FILE_APPEND);

if (!$data || empty($data->user_id)) {
    echo json_encode(["status" => "error", "message" => "Invalid data. Missing user_id."]);
    exit;
}

$uid = (string)$data->user_id;
$tid = (string)($data->tenant_id ?? $_GET['tenant_id'] ?? ''); // Check body first, then URL
$name = (string)($data->name ?? 'Guest');
$gender = (string)($data->gender ?? 'Male');
$is_anon = (int)($data->is_anonymous ?? 0);

if (empty($tid)) {
    echo json_encode(["status" => "error", "message" => "Missing restaurant identity (tenant_id)."]);
    exit;
}

try {
    // 1. Update/Insert customer profile
    $stmt = $conn->prepare("INSERT INTO customers (email, tenant_id, name, gender, is_anonymous)
                            VALUES (?, ?, ?, ?, ?)
                            ON DUPLICATE KEY UPDATE
                            name = ?, gender = ?, is_anonymous = ?");

    if (!$stmt) throw new Exception("Prepare failed (customers): " . $conn->error);

    $stmt->bind_param("ssssissi", $uid, $tid, $name, $gender, $is_anon, $name, $gender, $is_anon);

    if (!$stmt->execute()) {
        throw new Exception("Execute failed (customers): " . $stmt->error);
    }

    // 2. Update presence table so Nearby reflects changes instantly
    $pres = $conn->prepare("INSERT INTO restaurant_presence (user_id, tenant_id, table_number, user_name)
                            VALUES (?, ?, 0, ?)
                            ON DUPLICATE KEY UPDATE user_name = ?");

    if ($pres) {
        $pres->bind_param("ssss", $uid, $tid, $name, $name);
        $pres->execute();
    }

    echo json_encode(["status" => "success", "message" => "Profile successfully updated"]);
} catch (Exception $e) {
    // Return specific SQL error to Flutter for debugging
    echo json_encode(["status" => "error", "message" => "System Error: " . $e->getMessage()]);
}

$conn->close();
?>
