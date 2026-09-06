<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') exit;

require_once 'db_config.php';

$action = $_GET['action'] ?? '';
$tenant_id = $_GET['tenant_id'] ?? '';

try {
    switch ($action) {
        case 'get_offers':
            $stmt = $conn->prepare("SELECT * FROM marketing_offers WHERE tenant_id = :tid AND is_active = 1 ORDER BY created_at DESC");
            $stmt->execute(['tid' => $tenant_id]);
            echo json_encode(["status" => "success", "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
            break;

        case 'add_offer':
            $data = json_decode(file_get_contents('php://input'));
            $stmt = $conn->prepare("INSERT INTO marketing_offers (tenant_id, title, subtitle, discount_tag, image_url) VALUES (:tid, :title, :sub, :tag, :img)");
            $stmt->execute([
                'tid'   => $data->tenant_id,
                'title' => $data->title,
                'sub'   => $data->subtitle ?? '',
                'tag'   => $data->discount_tag ?? '',
                'img'   => $data->image_url ?? ''
            ]);
            echo json_encode(["status" => "success", "message" => "Offer added"]);
            break;

        case 'delete_offer':
            $id = $_GET['id'] ?? 0;
            $conn->prepare("DELETE FROM marketing_offers WHERE id = :id")->execute(['id' => $id]);
            echo json_encode(["status" => "success", "message" => "Offer deleted"]);
            break;

        default:
            echo json_encode(["status" => "error", "message" => "Invalid action"]);
            break;
    }
} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}
?>
