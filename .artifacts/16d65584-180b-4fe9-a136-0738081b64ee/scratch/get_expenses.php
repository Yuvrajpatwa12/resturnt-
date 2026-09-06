<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_config.php';

$tenant_id = $_GET['tenant_id'];

$sql = "SELECT * FROM expenses_v2 WHERE tenant_id = '$tenant_id' ORDER BY date DESC, id DESC";
$result = $conn->query($sql);

$data = [];
while($row = $result->fetch_assoc()) {
    $data[] = $row;
}

echo json_encode(["status" => "success", "data" => $data]);
$conn->close();
?>
