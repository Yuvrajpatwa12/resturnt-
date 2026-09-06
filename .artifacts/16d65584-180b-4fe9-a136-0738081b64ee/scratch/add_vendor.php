<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') exit;

require_once 'db_config.php';

$json = file_get_contents('php://input');
$data = json_decode($json);

if (!$data || empty($data->tenant_id) || empty($data->name)) {
    echo json_encode(["status" => "error", "message" => "Incomplete vendor data", "raw" => $json]);
    exit();
}

try {
    $sql = "INSERT INTO vendors (tenant_id, name, phone, email) VALUES (:tid, :name, :phone, :email)";
    $stmt = $conn->prepare($sql);

    $result = $stmt->execute([
        'tid' => $data->tenant_id,
        'name' => $data->name,
        'phone' => isset($data->phone) ? $data->phone : null,
        'email' => isset($data->email) ? $data->email : null
    ]);

    if ($result) {
        echo json_encode(["status" => "success", "message" => "Vendor registered"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to insert vendor"]);
    }
} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}
?>
