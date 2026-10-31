<?php
/**
 * theme_api.php - Restaurant Theme Management API
 * Handles CRUD operations for theme customization per restaurant
 */

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS, PUT");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';

// Auto-run schema setup
try {
    require_once 'theme_settings_setup.sql';
} catch (Throwable $e) {
    // Schema might already exist, continue
}

$action = $_GET['action'] ?? '';

// GET: Fetch theme for a specific tenant
if ($action === 'get_theme' && $_SERVER['REQUEST_METHOD'] === 'GET') {
    $tenant_id = $_GET['tenant_id'] ?? '';
    
    if (empty($tenant_id)) {
        echo json_encode(["status" => "error", "message" => "Tenant ID is required"]);
        exit;
    }
    
    try {
        $stmt = $conn->prepare("
            SELECT 
                primary_color,
                theme_name,
                secondary_color,
                background_color,
                font_family,
                border_radius,
                dark_mode_enabled,
                theme_updated_at
            FROM tenants 
            WHERE tenant_id = ? OR custom_domain = ?
            LIMIT 1
        ");
        $stmt->bind_param("ss", $tenant_id, $tenant_id);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($row = $result->fetch_assoc()) {
            echo json_encode([
                "status" => "success",
                "theme" => [
                    "primary_color" => $row['primary_color'] ?? '#FF5C00',
                    "theme_name" => $row['theme_name'] ?? 'Default Blue',
                    "secondary_color" => $row['secondary_color'] ?? '#002D62',
                    "background_color" => $row['background_color'] ?? '#F8FAFC',
                    "font_family" => $row['font_family'] ?? 'Inter',
                    "border_radius" => floatval($row['border_radius'] ?? 16.0),
                    "dark_mode_enabled" => boolval($row['dark_mode_enabled'] ?? 0),
                    "theme_updated_at" => $row['theme_updated_at']
                ]
            ]);
        } else {
            // Return default theme if tenant not found
            echo json_encode([
                "status" => "success",
                "theme" => [
                    "primary_color" => '#FF5C00',
                    "theme_name" => 'Default Blue',
                    "secondary_color" => '#002D62',
                    "background_color" => '#F8FAFC',
                    "font_family" => 'Inter',
                    "border_radius" => 16.0,
                    "dark_mode_enabled" => false,
                    "theme_updated_at" => null
                ]
            ]);
        }
    } catch (Throwable $e) {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
    }
    exit;
}

// POST/PUT: Update theme for a specific tenant
if ($action === 'update_theme' && ($_SERVER['REQUEST_METHOD'] === 'POST' || $_SERVER['REQUEST_METHOD'] === 'PUT')) {
    $json = file_get_contents('php://input');
    $data = json_decode($json);
    
    if (!$data) {
        echo json_encode(["status" => "error", "message" => "Invalid JSON payload"]);
        exit;
    }
    
    $tenant_id = trim((string)($data->tenant_id ?? ''));
    $primary_color = trim((string)($data->primary_color ?? '#FF5C00'));
    $theme_name = trim((string)($data->theme_name ?? 'Custom'));
    $secondary_color = trim((string)($data->secondary_color ?? '#002D62'));
    $background_color = trim((string)($data->background_color ?? '#F8FAFC'));
    $font_family = trim((string)($data->font_family ?? 'Inter'));
    $border_radius = floatval($data->border_radius ?? 16.0);
    $dark_mode_enabled = isset($data->dark_mode_enabled) ? ($data->dark_mode_enabled ? 1 : 0) : 0;
    
    if (empty($tenant_id)) {
        echo json_encode(["status" => "error", "message" => "Tenant ID is required"]);
        exit;
    }
    
    try {
        $stmt = $conn->prepare("
            UPDATE tenants 
            SET 
                primary_color = ?,
                theme_name = ?,
                secondary_color = ?,
                background_color = ?,
                font_family = ?,
                border_radius = ?,
                dark_mode_enabled = ?,
                theme_updated_at = NOW()
            WHERE tenant_id = ? OR custom_domain = ?
        ");
        $stmt->bind_param("sssssdiss", 
            $primary_color, 
            $theme_name, 
            $secondary_color, 
            $background_color, 
            $font_family, 
            $border_radius, 
            $dark_mode_enabled,
            $tenant_id,
            $tenant_id
        );
        
        if ($stmt->execute()) {
            echo json_encode([
                "status" => "success",
                "message" => "Theme updated successfully",
                "theme" => [
                    "primary_color" => $primary_color,
                    "theme_name" => $theme_name,
                    "secondary_color" => $secondary_color,
                    "background_color" => $background_color,
                    "font_family" => $font_family,
                    "border_radius" => $border_radius,
                    "dark_mode_enabled" => boolval($dark_mode_enabled)
                ]
            ]);
        } else {
            echo json_encode(["status" => "error", "message" => "Failed to update theme: " . $stmt->error]);
        }
    } catch (Throwable $e) {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
    }
    exit;
}

// GET: List all tenants with their themes (for admin panel)
if ($action === 'list_themes' && $_SERVER['REQUEST_METHOD'] === 'GET') {
    try {
        $stmt = $conn->prepare("
            SELECT 
                tenant_id,
                restaurant_name,
                custom_domain,
                primary_color,
                theme_name,
                secondary_color,
                background_color,
                font_family,
                border_radius,
                dark_mode_enabled,
                theme_updated_at
            FROM tenants
            ORDER BY restaurant_name ASC
        ");
        $stmt->execute();
        $result = $stmt->get_result();
        
        $themes = [];
        while ($row = $result->fetch_assoc()) {
            $themes[] = [
                "tenant_id" => $row['tenant_id'],
                "restaurant_name" => $row['restaurant_name'],
                "custom_domain" => $row['custom_domain'],
                "primary_color" => $row['primary_color'] ?? '#FF5C00',
                "theme_name" => $row['theme_name'] ?? 'Default Blue',
                "secondary_color" => $row['secondary_color'] ?? '#002D62',
                "background_color" => $row['background_color'] ?? '#F8FAFC',
                "font_family" => $row['font_family'] ?? 'Inter',
                "border_radius" => floatval($row['border_radius'] ?? 16.0),
                "dark_mode_enabled" => boolval($row['dark_mode_enabled'] ?? 0),
                "theme_updated_at" => $row['theme_updated_at']
            ];
        }
        
        echo json_encode([
            "status" => "success",
            "themes" => $themes,
            "count" => count($themes)
        ]);
    } catch (Throwable $e) {
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
    }
    exit;
}

// Invalid action
echo json_encode(["status" => "error", "message" => "Invalid action"]);

$conn->close();
?>
