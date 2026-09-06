<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once 'db_config.php';

$tenant_id = $_GET['tenant_id'];

try {
    $sql = "SELECT * FROM vendors WHERE tenant_id = :tid ORDER BY name ASC";
    $stmt = $conn->prepare($sql);
    $stmt->execute(['tid' => $tenant_id]);

    $data = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode(["status" => "success", "data" => $data]);
} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}
?>
