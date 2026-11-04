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
function refundPaymentRespond($status, $payload) {
    http_response_code($status);
    echo json_encode($payload);
    exit;
}
require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/staff_auth.php';
require_once __DIR__ . '/billing_common.php';
require_once __DIR__ . '/financial_common.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    refundPaymentRespond(405, ['status' => 'error', 'message' => 'POST is required']);
}
$auth = requireAuth($conn, ['super_admin']);
$staff = isset($auth['user']) && is_array($auth['user']) ? $auth['user'] : [];
if (trim((string)($staff['tenant_id'] ?? '')) === '' || (int)($staff['id'] ?? 0) <= 0) {
    refundPaymentRespond(401, ['status' => 'error', 'message' => 'Authenticated staff identity is incomplete']);
}
financialEnsureSchema($conn);
$data = json_decode(file_get_contents('php://input'), true);
$paymentIdValue = $data['payment_id'] ?? 0;
$paymentId = is_scalar($paymentIdValue) ? (int)$paymentIdValue : 0;
$refundCents = financialAmountCents($data['refund_amount'] ?? '');
$reasonValue = $data['reason'] ?? '';
$reason = is_string($reasonValue) ? trim($reasonValue) : '';
if ($paymentId <= 0 || $refundCents === null || $refundCents <= 0 ||
    $reason === '' || strlen($reason) > 2000) {
    refundPaymentRespond(400, [
        'status' => 'error',
        'message' => 'A valid payment_id, positive refund_amount and refund reason are required'
    ]);
}
$tenantId = (string)$staff['tenant_id'];
$staffId = (int)$staff['id'];
try {
    $conn->begin_transaction();
    $paymentStmt = $conn->prepare(
        "SELECT id, amount, status FROM payments
         WHERE id = ? AND tenant_id = ? LIMIT 1 FOR UPDATE"
    );
    $paymentStmt->bind_param('is', $paymentId, $tenantId);
    $paymentStmt->execute();
    $payment = $paymentStmt->get_result()->fetch_assoc();
    $paymentStmt->close();
    if (!$payment || $payment['status'] !== 'Completed') {
        $conn->rollback();
        refundPaymentRespond(404, ['status' => 'error', 'message' => 'Completed payment was not found for this tenant']);
    }
    $refundSum = $conn->prepare(
        'SELECT COALESCE(SUM(amount), 0) AS refunded_amount
         FROM refunds WHERE payment_id = ? AND tenant_id = ?'
    );
    $refundSum->bind_param('is', $paymentId, $tenantId);
    $refundSum->execute();
    $alreadyRefundedCents = (int)round(
        (float)$refundSum->get_result()->fetch_assoc()['refunded_amount'] * 100
    );
    $refundSum->close();
    $originalCents = (int)round((float)$payment['amount'] * 100);
    $remainingCents = $originalCents - $alreadyRefundedCents;
    if ($refundCents > $remainingCents) {
        $conn->rollback();
        refundPaymentRespond(409, [
            'status' => 'error',
            'message' => 'Refund exceeds the remaining refundable amount for this payment',
            'remaining_refundable' => number_format(max(0, $remainingCents) / 100, 2, '.', '')
        ]);
    }
    $amount = number_format($refundCents / 100, 2, '.', '');
    $insert = $conn->prepare(
        'INSERT INTO refunds (payment_id, tenant_id, amount, reason, staff_id)
         VALUES (?, ?, ?, ?, ?)'
    );
    $insert->bind_param('sisss', $paymentId, $tenantId, $amount, $reason, $staffId);
    $insert->execute();
    $refundId = (int)$conn->insert_id;
    $insert->close();
    $conn->commit();
    refundPaymentRespond(200, [
        'status' => 'success',
        'refund_id' => $refundId,
        'payment_id' => $paymentId,
        'refund_amount' => $amount,
        'remaining_refundable' => number_format(($remainingCents - $refundCents) / 100, 2, '.', ''),
        'message' => 'Refund recorded successfully'
    ]);
} catch (Throwable $error) {
    try { $conn->rollback(); } catch (Throwable $ignored) {}
    error_log('Payment refund failed: ' . $error->getMessage());
    refundPaymentRespond(500, ['status' => 'error', 'message' => 'Could not record this refund']);
}
?>
