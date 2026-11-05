<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=UTF-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

require_once __DIR__ . '/db_config.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        echo json_encode(['status' => 'error', 'message' => 'POST method is required']);
        exit;
    }

    $rawInput = file_get_contents('php://input');
    $data = json_decode($rawInput, true);

    if (!is_array($data)) {
        echo json_encode(['status' => 'error', 'message' => 'Invalid JSON input']);
        exit;
    }

    $tenantId = trim((string)($data['tenant_id'] ?? ''));
    if (empty($tenantId)) {
        echo json_encode(['status' => 'error', 'message' => 'Tenant ID is required']);
        exit;
    }

    $restaurantName = trim((string)($data['restaurant_name'] ?? ''));
    $domain = trim((string)($data['domain'] ?? ''));
    $customDomain = trim((string)($data['custom_domain'] ?? ''));
    $contactEmail = trim((string)($data['contact_email'] ?? ''));
    $contactPhone = trim((string)($data['contact_phone'] ?? ''));
    $location = trim((string)($data['location'] ?? $data['address'] ?? ''));
    $color = trim((string)($data['color'] ?? $data['primary_color'] ?? '#FF5C00'));
    $fontFamily = trim((string)($data['font_family'] ?? 'Inter'));
    $logoUrl = trim((string)($data['logo_url'] ?? ''));
    $vatPercentage = isset($data['vat_percentage']) ? (float)$data['vat_percentage'] : 0.0;
    $serviceCharge = isset($data['service_charge_percentage']) ? (float)$data['service_charge_percentage'] : (isset($data['service_charge']) ? (float)$data['service_charge'] : 0.0);

    // Auto-ensure schema columns exist on `tenants`
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS domain VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS restaurant_name VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS custom_domain VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS logo_url TEXT");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS contact_email VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(50) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS location VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS address VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS color VARCHAR(7) DEFAULT '#FF5C00'");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS primary_color VARCHAR(7) DEFAULT '#FF5C00'");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS font_family VARCHAR(50) DEFAULT 'Inter'");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS vat_percentage DECIMAL(5,2) DEFAULT 0.00");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS service_charge_percentage DECIMAL(5,2) DEFAULT 0.00");

    // Update main tenants table (support tenant_id, domain, or custom_domain match)
    $stmt = $conn->prepare("UPDATE tenants SET
        restaurant_name = ?,
        domain = COALESCE(NULLIF(?, ''), domain),
        custom_domain = ?,
        logo_url = COALESCE(NULLIF(?, ''), logo_url),
        contact_email = ?,
        contact_phone = ?,
        location = ?,
        address = ?,
        color = ?,
        font_family = ?,
        vat_percentage = ?,
        service_charge_percentage = ?
        WHERE tenant_id = ? OR domain = ? OR custom_domain = ?");

    $stmt->bind_param(
        "ssssssssssddsss",
        $restaurantName,
        $domain,
        $customDomain,
        $logoUrl,
        $contactEmail,
        $contactPhone,
        $location,
        $location,
        $color,
        $fontFamily,
        $vatPercentage,
        $serviceCharge,
        $tenantId,
        $tenantId,
        $tenantId
    );

    $stmt->execute();
    $stmt->close();

    // Also upsert into `tenant_settings` if table exists
    @$conn->query("CREATE TABLE IF NOT EXISTS tenant_settings (
        tenant_id VARCHAR(50) PRIMARY KEY,
        vat_percentage DECIMAL(5,2) DEFAULT 0.00,
        service_charge DECIMAL(5,2) DEFAULT 0.00,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    $tsStmt = $conn->prepare("INSERT INTO tenant_settings (tenant_id, vat_percentage, service_charge, updated_at)
        VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            vat_percentage = VALUES(vat_percentage),
            service_charge = VALUES(service_charge),
            updated_at = NOW()");
    $tsStmt->bind_param("sdd", $tenantId, $vatPercentage, $serviceCharge);
    $tsStmt->execute();
    $tsStmt->close();

    echo json_encode([
        'status' => 'success',
        'message' => 'Restaurant profile updated successfully!',
        'tenant' => [
            'tenant_id' => $tenantId,
            'restaurant_name' => $restaurantName,
            'name' => $restaurantName,
            'domain' => $domain,
            'custom_domain' => $customDomain,
            'contact_email' => $contactEmail,
            'admin_email' => $contactEmail,
            'contact_phone' => $contactPhone,
            'phone' => $contactPhone,
            'location' => $location,
            'address' => $location,
            'color' => $color,
            'primary_color' => $color,
            'font_family' => $fontFamily,
            'vat_percentage' => $vatPercentage,
            'service_charge_percentage' => $serviceCharge
        ]
    ]);

} catch (Throwable $e) {
    error_log("Super Admin Update Tenant Error: " . $e->getMessage());
    echo json_encode([
        'status' => 'error',
        'message' => 'Failed to update tenant profile: ' . $e->getMessage()
    ]);
}
?>
