<?php
// get_tables.php - Fetches all tables for a specific restaurant
require_once 'db_config.php';

$tid = $_GET['tenant_id'] ?? '';

if (!empty($tid)) {
    try {
        $stmt = $conn->prepare("SELECT * FROM restaurant_tables WHERE tenant_id = :tid ORDER BY table_number ASC");
        $stmt->execute(['tid' => $tid]);
        echo json_encode(["status" => "success", "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    } catch(PDOException $e) {
        echo json_encode(["status" => "error", "message" => $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Tenant ID missing."]);
}
?>
