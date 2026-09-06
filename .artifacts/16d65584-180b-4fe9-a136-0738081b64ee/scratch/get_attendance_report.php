<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_config.php';

$tenant_id = $_GET['tenant_id'];
$start = $_GET['start'];
$end = $_GET['end'];

$sql = "SELECT a.*, u.name
        FROM attendance a
        JOIN users u ON a.user_id = u.id
        WHERE a.tenant_id = '$tenant_id' AND a.date BETWEEN '$start' AND '$end'
        ORDER BY a.date DESC";

$result = $conn->query($sql);

$data = [];
while($row = $result->fetch_assoc()) {
    $data[] = $row;
}

echo json_encode(["status" => "success", "data" => $data]);
$conn->close();
?>
