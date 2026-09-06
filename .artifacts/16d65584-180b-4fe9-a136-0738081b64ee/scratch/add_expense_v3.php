<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') exit;

require_once 'db_config.php';

$json = file_get_contents('php://input');
$data = json_decode($json);

if (!$data || empty($data->tenant_id)) {
    echo json_encode(["status" => "error", "message" => "Incomplete expense data", "raw" => $json]);
    exit();
}

try {
    $sql = "INSERT INTO expenses_v3 (tenant_id, category, amount, payment_mode, vendor_id, note, date)
            VALUES (:tid, :cat, :amt, :mode, :vid, :note, :date)";
    $stmt = $conn->prepare($sql);

    $result = $stmt->execute([
        'tid'   => $data->tenant_id,
        'cat'   => $data->category,
        'amt'   => $data->amount,
        'mode'  => $data->payment_mode,
        'vid'   => isset($data->vendor_id) ? $data->vendor_id : null,
        'note'  => isset($data->note) ? $data->note : '',
        'date'  => $data->date
    ]);

    if ($result) {
        echo json_encode(["status" => "success", "message" => "Expense saved"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to insert expense"]);
    }
} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}
?>
