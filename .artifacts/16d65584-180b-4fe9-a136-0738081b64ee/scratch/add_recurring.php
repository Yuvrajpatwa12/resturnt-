<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') exit;

require_once 'db_config.php';

$json = file_get_contents('php://input');
$data = json_decode($json);

if (!$data || empty($data->tenant_id) || empty($data->title)) {
    echo json_encode(["status" => "error", "message" => "Incomplete subscription data", "raw" => $json]);
    exit();
}

try {
    $sql = "INSERT INTO recurring_expenses (tenant_id, title, category, amount, frequency, next_due_date)
            VALUES (:tid, :title, :cat, :amt, :freq, :next)";
    $stmt = $conn->prepare($sql);

    $result = $stmt->execute([
        'tid' => $data->tenant_id,
        'title' => $data->title,
        'cat' => $data->category,
        'amt' => $data->amount,
        'freq' => $data->frequency,
        'next' => $data->next_due_date
    ]);

    if ($result) {
        echo json_encode(["status" => "success", "message" => "Recurring expense set"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to insert record"]);
    }
} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}
?>
