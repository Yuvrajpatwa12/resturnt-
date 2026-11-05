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
    $isActive = isset($data['is_active']) ? (int)$data['is_active'] : 1;

    if (empty($tenantId)) {
        echo json_encode(['status' => 'error', 'message' => 'Tenant ID is required']);
        exit;
    }

    if ($isActive !== 0 && $isActive !== 1) {
        echo json_encode(['status' => 'error', 'message' => 'is_active must be 0 or 1']);
        exit;
    }

    $subscriptionStatus = $isActive === 1 ? 'Active' : 'Pending';

    // Auto-ensure columns exist
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS is_active TINYINT(1) DEFAULT 1");
    @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS subscription_status VARCHAR(50) DEFAULT 'Active'");

    $conn->begin_transaction();

    $lookup = $conn->prepare("SELECT tenant_id FROM tenants
        WHERE tenant_id = ? OR domain = ? OR custom_domain = ?
        LIMIT 1 FOR UPDATE");
    $lookup->bind_param("sss", $tenantId, $tenantId, $tenantId);
    $lookup->execute();
    $tenant = $lookup->get_result()->fetch_assoc();
    $lookup->close();

    if (!$tenant) {
        $conn->rollback();
        echo json_encode([
            'status' => 'error',
            'message' => 'Tenant ID [' . $tenantId . '] not found in database'
        ]);
        exit;
    }

    // Use the canonical tenant ID and treat an unchanged row as a successful update.
    $stmt = $conn->prepare("UPDATE tenants SET
        is_active = ?,
        subscription_status = ?
        WHERE tenant_id = ?");

    $stmt->bind_param("iss", $isActive, $subscriptionStatus, $tenant['tenant_id']);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close();
    $conn->commit();

    echo json_encode([
        'status' => 'success',
        'message' => $isActive === 1 ? 'Restaurant successfully approved and activated!' : 'Restaurant blocked successfully.',
        'is_active' => $isActive,
        'subscription_status' => $subscriptionStatus,
        'affected_rows' => $affected,
        'already_in_requested_state' => $affected === 0
    ]);

} catch (Throwable $e) {
    if (isset($conn) && $conn instanceof mysqli) {
        $conn->rollback();
    }
    error_log("Super Admin Toggle Tenant Status Error: " . $e->getMessage());
    echo json_encode([
        'status' => 'error',
        'message' => 'Failed to update status: ' . $e->getMessage()
    ]);
}
?>
