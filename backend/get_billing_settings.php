<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}
require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/staff_auth.php';
require_once __DIR__ . '/billing_common.php';

try {
    $staff = billingAuthTenant($conn, ['admin', 'cashier', 'waiter']);
    billingEnsureSchema($conn);
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        billingRespond(405, ['status' => 'error', 'message' => 'GET is required']);
    }
    $rates = billingGetRates($conn, (string)$staff['tenant_id']);
    billingRespond(200, ['status' => 'success'] + $rates);
} catch (BillingConfigurationException $error) {
    billingRespond(409, ['status' => 'error', 'message' => $error->getMessage()]);
} catch (Throwable $error) {
    error_log('Billing settings lookup failed: ' . $error->getMessage());
    billingRespond(500, ['status' => 'error', 'message' => 'Could not load billing settings']);
}
?>
