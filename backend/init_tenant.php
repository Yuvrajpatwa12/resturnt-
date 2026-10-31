<?php
/**
 * init_tenant.php - Robust Multi-Tenant Handler
 * Detects the restaurant based on domain or custom_domain.
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

if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Database connection failed"]));
}

$action = $_GET['action'] ?? '';
$domain = $_GET['domain'] ?? '';

if ($action === 'update_currency') {
    $json = file_get_contents('php://input');
    $data = json_decode($json);
    $tenant_id = trim((string)($data->tenant_id ?? ''));
    $currency_code = trim((string)($data->currency_code ?? 'NPR'));
    $currency_symbol = trim((string)($data->currency_symbol ?? 'Rs.'));

    if (empty($tenant_id)) {
        echo json_encode(["status" => "error", "message" => "Tenant ID required"]);
        exit;
    }

    $stmt = $conn->prepare("UPDATE tenants SET currency_code = ?, currency_symbol = ? WHERE tenant_id = ?");
    $stmt->bind_param("sss", $currency_code, $currency_symbol, $tenant_id);
    if ($stmt->execute()) {
        echo json_encode(["status" => "success"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to update currency"]);
    }
    exit;
} else if ($action === 'update_location') {
    $json = file_get_contents('php://input');
    $data = json_decode($json);
    $tenant_id = trim((string)($data->tenant_id ?? ''));
    $lat = $data->latitude ?? null;
    $lng = $data->longitude ?? null;

    if (empty($tenant_id)) {
        echo json_encode(["status" => "error", "message" => "Tenant ID required"]);
        exit;
    }

    $stmt = $conn->prepare("UPDATE tenants SET latitude = ?, longitude = ? WHERE tenant_id = ?");
    $stmt->bind_param("dds", $lat, $lng, $tenant_id);
    if ($stmt->execute()) {
        echo json_encode(["status" => "success"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to update location"]);
    }
    exit;
} else if ($action === 'update_profile') {
    $json = file_get_contents('php://input');
    $data = json_decode($json);
    $tenant_id = trim((string)($data->tenant_id ?? ''));
    $restaurant_name = trim((string)($data->restaurant_name ?? ''));
    $contact_email = trim((string)($data->contact_email ?? ''));
    $contact_phone = trim((string)($data->contact_phone ?? ''));
    $location = trim((string)($data->location ?? ''));

    if (empty($tenant_id)) {
        echo json_encode(["status" => "error", "message" => "Tenant ID required"]);
        exit;
    }

    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS contact_email VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(50) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS location VARCHAR(255) DEFAULT ''");

    $stmt = $conn->prepare("UPDATE tenants SET restaurant_name = ?, contact_email = ?, contact_phone = ?, location = ? WHERE tenant_id = ? OR custom_domain = ?");
    $stmt->bind_param("ssssss", $restaurant_name, $contact_email, $contact_phone, $location, $tenant_id, $tenant_id);
    if ($stmt->execute()) {
        echo json_encode([
            "status" => "success",
            "message" => "Restaurant profile saved successfully!",
            "profile" => [
                "restaurant_name" => $restaurant_name,
                "contact_email" => $contact_email,
                "contact_phone" => $contact_phone,
                "location" => $location
            ]
        ]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to update tenant profile in database"]);
    }
    exit;
}

if (empty($domain)) {
    echo json_encode(["status" => "error", "message" => "No domain provided"]);
    exit;
}

// Support for www and non-www
$domain_no_www = str_replace('www.', '', $domain);
$domain_with_www = 'www.' . $domain_no_www;

try {
    // Auto-add profile & theme columns if they don't exist
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS contact_email VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(50) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS location VARCHAR(255) DEFAULT ''");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS theme_name VARCHAR(50) DEFAULT 'Default Blue'");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS secondary_color VARCHAR(7) DEFAULT '#002D62'");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS background_color VARCHAR(7) DEFAULT '#F8FAFC'");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS font_family VARCHAR(50) DEFAULT 'Inter'");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS border_radius DECIMAL(4,1) DEFAULT 16.0");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS dark_mode_enabled TINYINT(1) DEFAULT 0");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS theme_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP");
    
    // Check custom_domain column first
    $stmt = $conn->prepare("SELECT * FROM tenants WHERE custom_domain = ? OR custom_domain = ? OR tenant_id = ? LIMIT 1");
    $stmt->bind_param("sss", $domain_no_www, $domain_with_www, $domain_no_www);
    $stmt->execute();
    $res = $stmt->get_result();

    if ($res->num_rows > 0) {
        $tenant = $res->fetch_assoc();
        // Cast numeric fields to proper types
        if (isset($tenant['border_radius'])) {
            $tenant['border_radius'] = floatval($tenant['border_radius']);
        }
        if (isset($tenant['dark_mode_enabled'])) {
            $tenant['dark_mode_enabled'] = boolval($tenant['dark_mode_enabled']);
        }
        if (isset($tenant['latitude'])) {
            $tenant['latitude'] = floatval($tenant['latitude']);
        }
        if (isset($tenant['longitude'])) {
            $tenant['longitude'] = floatval($tenant['longitude']);
        }
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
