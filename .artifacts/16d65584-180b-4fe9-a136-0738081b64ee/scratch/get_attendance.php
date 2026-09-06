<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_config.php';

$tenant_id = $_GET['tenant_id'];
$date = $_GET['date'];

$sql = "SELECT user_id, status FROM attendance WHERE tenant_id = '$tenant_id' AND date = '$date'";
$result = $conn->query($sql);

$data = [];
while($row = $result->fetch_assoc()) {
    $data[] = $row;
}

echo json_encode(["status" => "success", "data" => $data]);
$conn->close();
?>
