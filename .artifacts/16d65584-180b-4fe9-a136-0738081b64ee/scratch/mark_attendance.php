<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') exit;

include_once 'db_config.php';

$json = file_get_contents('php://input');
$data = json_decode($json);

if (!$data || empty($data->attendance)) {
    echo json_encode(["status" => "error", "message" => "No data received"]);
    exit();
}

$success_count = 0;
$stmt = $conn->prepare("INSERT INTO attendance (tenant_id, user_id, date, status)
                        VALUES (?, ?, ?, ?)
                        ON DUPLICATE KEY UPDATE status = ?");

foreach ($data->attendance as $row) {
    $uid = (int)$row->user_id;
    $stmt->bind_param("sisss", $row->tenant_id, $uid, $row->date, $row->status, $row->status);
    if ($stmt->execute()) {
        $success_count++;
    }
}

echo json_encode(["status" => "success", "marked" => $success_count]);

$stmt->close();
$conn->close();
?>
