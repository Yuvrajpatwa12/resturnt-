<?php
// delete_table.php - Removes a table from the system
require_once 'db_config.php';

$data = json_decode(file_get_contents("php://input"));

if (!empty($data->table_id)) {
    try {
        $stmt = $conn->prepare("DELETE FROM restaurant_tables WHERE id = :id");
        $stmt->execute(['id' => $data->table_id]);
        echo json_encode(["status" => "success", "message" => "Table deleted successfully!"]);
    } catch(PDOException $e) {
        echo json_encode(["status" => "error", "message" => $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Table ID missing."]);
}
?>
