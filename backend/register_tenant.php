<?php
/**
 * register_tenant.php - New Restaurant Tenant Signup with Auto 3-Day Free Trial
 */

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';

$json = file_get_contents('php://input');
$data = json_decode($json);

if (!$data) {
    echo json_encode(["status" => "error", "message" => "Invalid JSON payload"]);
    exit;
}

$tenant_id = trim((string)($data->tenant_id ?? ''));
$restaurant_name = trim((string)($data->restaurant_name ?? $data->name ?? ''));
$custom_domain = trim((string)($data->custom_domain ?? $data->domain ?? ''));
$email = trim((string)($data->email ?? $data->contact_email ?? ''));
$primary_color = trim((string)($data->primary_color ?? '#FF5C00'));
$logo_url = trim((string)($data->logo_url ?? ''));

if (empty($tenant_id) || empty($restaurant_name)) {
    echo json_encode(["status" => "error", "message" => "Tenant ID and Restaurant Name are required."]);
    exit;
}

try {
    // Auto-ensure schema columns exist
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS subscription_status VARCHAR(50) DEFAULT 'Trial'");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS trial_start DATETIME DEFAULT NULL");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS trial_end DATETIME DEFAULT NULL");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS subscription_start DATETIME DEFAULT NULL");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS subscription_end DATETIME DEFAULT NULL");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS primary_email VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS contact_email VARCHAR(255) DEFAULT ''");

    // Check if tenant_id or domain already exists
    if (!empty($custom_domain)) {
        $chk = $conn->prepare("SELECT tenant_id FROM tenants WHERE tenant_id = ? OR custom_domain = ? LIMIT 1");
        $chk->bind_param("ss", $tenant_id, $custom_domain);
    } else {
        $chk = $conn->prepare("SELECT tenant_id FROM tenants WHERE tenant_id = ? LIMIT 1");
        $chk->bind_param("s", $tenant_id);
    }
    $chk->execute();
    if ($chk->get_result()->num_rows > 0) {
        echo json_encode(["status" => "error", "message" => "A restaurant with this ID or domain is already registered."]);
        exit;
    }
    $chk->close();

    // NEW TENANT: Inactive until Super Admin approves subscription
    $stmt = $conn->prepare("
        INSERT INTO tenants (
            tenant_id, restaurant_name, custom_domain, primary_color, logo_url,
            primary_email, contact_email,
            is_active, plan, subscription_status, trial_start, trial_end,
            subscription_start, subscription_end, created_at
        ) VALUES (
            ?, ?, ?, ?, ?,
            ?, ?,
            0, 'Pending Approval', 'Pending', NULL, NULL,
            NULL, NULL, NOW()
        )
    ");
    $stmt->bind_param("sssssss", $tenant_id, $restaurant_name, $custom_domain, $primary_color, $logo_url, $email, $email);

    if ($stmt->execute()) {
        echo json_encode([
            "status" => "success",
            "message" => "Tenant registered successfully! Awaiting Super Admin subscription approval.",
            "tenant_id" => $tenant_id,
            "plan" => "Pending Approval",
            "subscription_status" => "Pending"
        ]);
    } else {
        echo json_encode(["status" => "error", "message" => "Database error inserting tenant: " . $stmt->error]);
    }
    $stmt->close();

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "System error: " . $e->getMessage()]);
}

$conn->close();
?>
