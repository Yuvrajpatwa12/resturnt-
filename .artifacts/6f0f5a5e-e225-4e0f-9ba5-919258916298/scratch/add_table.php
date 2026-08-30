<?php
// add_table.php - Registers a new table for a restaurant
require_once 'db_config.php';

$data = json_decode(file_get_contents("php://input"));

if (!empty($data->tenant_id) && !empty($data->table_number)) {
    try {
        $query = "INSERT INTO restaurant_tables (tenant_id, table_number, status) VALUES (:tid, :tnum, 'Available')";
        $stmt = $conn->prepare($query);
        $stmt->execute(['tid' => $data->tenant_id, 'tnum' => $data->table_number]);
        echo json_encode(["status" => "success", "message" => "Table added successfully!"]);
    } catch(PDOException $e) {
        echo json_encode(["status" => "error", "message" => $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Incomplete data provided."]);
}
?>
