<?php
/**
 * init_tenant.php - Robust Multi-Tenant Handler
 * Detects the restaurant based on domain or custom_domain.
 */
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once 'db_config.php';

if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Database connection failed"]));
}

$domain = $_GET['domain'] ?? '';

if (empty($domain)) {
    echo json_encode(["status" => "error", "message" => "No domain provided"]);
    exit;
}

// Support for www and non-www
$domain_no_www = str_replace('www.', '', $domain);
$domain_with_www = 'www.' . $domain_no_www;

try {
    // Check custom_domain column first
    $stmt = $conn->prepare("SELECT * FROM tenants WHERE custom_domain = ? OR custom_domain = ? OR tenant_id = ? LIMIT 1");
    $stmt->bind_param("sss", $domain_no_www, $domain_with_www, $domain_no_www);
    $stmt->execute();
    $res = $stmt->get_result();

    if ($res->num_rows > 0) {
        $tenant = $res->fetch_assoc();
        echo json_encode([
            "status" => "success",
            "data" => $tenant
        ]);
    } else {
        // Fallback: see if it's the primary system domain
        echo json_encode([
            "status" => "error",
            "message" => "Domain [$domain] is not registered as a tenant."
        ]);
    }

} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}

$conn->close();
?>
