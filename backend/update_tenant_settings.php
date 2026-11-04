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
require_once __DIR__ . '/staff_auth.php';
require_once __DIR__ . '/billing_common.php';

try {
    $staff = billingAuthTenant($conn, ['admin', 'super_admin']);
    billingEnsureSchema($conn);
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        billingRespond(405, ['status' => 'error', 'message' => 'POST is required']);
    }
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) {
        billingRespond(400, ['status' => 'error', 'message' => 'Invalid JSON request']);
    }
    $vatValue = $data['vat_percentage'] ?? null;
    $serviceValue = $data['service_charge'] ?? null;
    $ratePattern = '/^(?:\d{1,3}(?:\.\d{1,3})?|\.\d{1,3})$/';
    if (!is_scalar($vatValue) || !is_scalar($serviceValue) ||
        !preg_match($ratePattern, trim((string)$vatValue)) ||
        !preg_match($ratePattern, trim((string)$serviceValue))) {
        billingRespond(400, ['status' => 'error', 'message' => 'Tax and service charge rates must be valid percentages with at most three decimal places']);
    }
    $vat = (float)$vatValue;
    $service = (float)$serviceValue;
    if (!is_finite($vat) || !is_finite($service) ||
        $vat < 0 || $vat > 100 || $service < 0 || $service > 100) {
        billingRespond(400, ['status' => 'error', 'message' => 'Tax and service charge rates must be between 0 and 100']);
    }
    $tenantId = (string)$staff['tenant_id'];

    // Ensure explicit collation during upsert if needed
    $stmt = $conn->prepare('INSERT INTO tenant_settings (tenant_id, vat_percentage, service_charge, updated_at)
        VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            vat_percentage = VALUES(vat_percentage),
            service_charge = VALUES(service_charge),
            updated_at = NOW()');
    $stmt->bind_param('sdd', $tenantId, $vat, $service);
    $stmt->execute();
    $stmt->close();

    billingRespond(200, [
        'status' => 'success',
        'vat_percentage' => $vat,
        'service_charge' => $service
    ]);
} catch (Throwable $error) {
    error_log('Tenant settings update failed: ' . $error->getMessage());
    billingRespond(500, ['status' => 'error', 'message' => 'Could not update tenant settings']);
}
?>
