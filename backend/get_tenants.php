<?php
/**
 * Super Admin - Fetch All Registered Tenants
 * Place this in public_html/saas_api/
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Pragma: no-cache");
header("Expires: 0");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/super_admin_api.php';

if (!isset($conn) || $conn->connect_error) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "DB Connection Failed"]);
    exit;
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        http_response_code(405);
        echo json_encode(["status" => "error", "message" => "GET is required"]);
        exit;
    }

    if (!verifySuperAdminSession($conn)) {
        http_response_code(401);
        echo json_encode(["status" => "error", "message" => "Super administrator authentication is required"]);
        exit;
    }

    // Fetch all tenants with some basic stats
    $sql = "SELECT t.*,
            (SELECT COUNT(*) FROM orders o WHERE o.tenant_id = t.tenant_id) as total_orders,
            (SELECT COUNT(*) FROM staff s WHERE s.tenant_id = t.tenant_id) as active_staff
            FROM tenants t
            ORDER BY t.created_at DESC";

    $result = $conn->query($sql);

    $tenants = [];
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            // Add some display helpers
            $row['storage_display'] = "0.0 GB"; // Placeholder
            $tenants[] = $row;
        }
        echo json_encode(["status" => "success", "data" => $tenants]);
    } else {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Database Query Error: " . $conn->error]);
    }

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Could not load tenants"]);
}

$conn->close();
?>
