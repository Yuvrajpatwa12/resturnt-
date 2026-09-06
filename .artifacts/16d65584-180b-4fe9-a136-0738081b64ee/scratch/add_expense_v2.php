<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') exit;

include_once 'db_config.php';

$json = file_get_contents('php://input');
$data = json_decode($json, true);

if (!$data || !isset($data['tenant_id'])) {
    echo json_encode(["status" => "error", "message" => "Incomplete data"]);
    exit();
}

$tenant_id = $conn->real_escape_string($data['tenant_id']);
$category = $conn->real_escape_string($data['category']);
$amount = (float)$data['amount'];
$account = $conn->real_escape_string($data['account']);
$note = $conn->real_escape_string($data['note']);
$date = $conn->real_escape_string($data['date']);
$is_income = (int)$data['is_income'];

$sql = "INSERT INTO expenses_v2 (tenant_id, category, amount, account, note, date, is_income)
        VALUES ('$tenant_id', '$category', $amount, '$account', '$note', '$date', $is_income)";

if ($conn->query($sql)) {
    echo json_encode(["status" => "success", "message" => "Expense saved"]);
} else {
    echo json_encode(["status" => "error", "message" => $conn->error]);
}

$conn->close();
?>
