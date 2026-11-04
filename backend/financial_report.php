<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=UTF-8');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}
require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/staff_auth.php';
require_once __DIR__ . '/billing_common.php';
require_once __DIR__ . '/financial_common.php';

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        billingRespond(405, ['status' => 'error', 'message' => 'GET is required']);
    }
    $staff = financialAuthUser($conn, ['admin', 'cashier', 'super_admin']);
    financialEnsureSchema($conn);
    billingEnsureSchema($conn);
    $tenantId = (string)$staff['tenant_id'];
    $from = trim((string)($_GET['from'] ?? ''));
    $to = trim((string)($_GET['to'] ?? ''));
    $datePattern = '/^\d{4}-\d{2}-\d{2}$/';
    if (!preg_match($datePattern, $from) || !preg_match($datePattern, $to) ||
        !checkdate((int)substr($from, 5, 2), (int)substr($from, 8, 2), (int)substr($from, 0, 4)) ||
        !checkdate((int)substr($to, 5, 2), (int)substr($to, 8, 2), (int)substr($to, 0, 4)) ||
        $from > $to) {
        billingRespond(400, ['status' => 'error', 'message' => 'Provide a valid from/to date range (YYYY-MM-DD)']);
    }
    $toExclusiveTimestamp = strtotime($to . ' +1 day');
    if ($toExclusiveTimestamp === false) {
        billingRespond(400, ['status' => 'error', 'message' => 'The end date is outside the supported range']);
    }
    $toExclusive = date('Y-m-d', $toExclusiveTimestamp);

    $placedStmt = $conn->prepare(
        "SELECT COUNT(*) AS order_count, COALESCE(SUM(total_amount), 0) AS order_subtotal
         FROM orders
         WHERE tenant_id = ? AND created_at >= ? AND created_at < ?
           AND LOWER(status) <> 'voided'"
    );
    $placedStmt->bind_param('sss', $tenantId, $from, $toExclusive);
    $placedStmt->execute();
    $placed = $placedStmt->get_result()->fetch_assoc();
    $placedStmt->close();

    $paidStmt = $conn->prepare(
        "SELECT COUNT(*) AS order_count, COALESCE(SUM(o.total_amount), 0) AS order_subtotal
         FROM orders o
         WHERE o.tenant_id = ? AND o.created_at >= ? AND o.created_at < ?
           AND LOWER(o.status) <> 'voided'
           AND EXISTS (
               SELECT 1 FROM payments p
               INNER JOIN dining_sessions ds ON ds.id = p.session_id
               LEFT JOIN payment_orders po ON po.payment_id = p.id
               WHERE (po.order_id = o.id OR p.order_id = o.id)
                 AND p.tenant_id = o.tenant_id
                 AND p.status = 'Completed' AND ds.tenant_id = o.tenant_id
                 AND ds.status = 'Settled'
           )"
    );
    $paidStmt->bind_param('sss', $tenantId, $from, $toExclusive);
    $paidStmt->execute();
    $paidOrders = $paidStmt->get_result()->fetch_assoc();
    $paidStmt->close();

    $openStmt = $conn->prepare(
        "SELECT COUNT(*) AS order_count, COALESCE(SUM(o.total_amount), 0) AS order_subtotal
         FROM orders o
         INNER JOIN dining_sessions ds ON ds.id = o.session_id AND ds.tenant_id = o.tenant_id
         WHERE o.tenant_id = ? AND o.created_at >= ? AND o.created_at < ?
           AND LOWER(o.status) NOT IN ('settled', 'voided')
           AND ds.status IN ('Open', 'ReadyForBilling')"
    );
    $openStmt->bind_param('sss', $tenantId, $from, $toExclusive);
    $openStmt->execute();
    $openOrders = $openStmt->get_result()->fetch_assoc();
    $openStmt->close();

    $readyStmt = $conn->prepare(
        "SELECT COUNT(*) AS session_count
         FROM dining_sessions
         WHERE tenant_id = ? AND status = 'ReadyForBilling'
           AND last_modified >= ? AND last_modified < ?"
    );
    $readyStmt->bind_param('sss', $tenantId, $from, $toExclusive);
    $readyStmt->execute();
    $readySessions = (int)$readyStmt->get_result()->fetch_assoc()['session_count'];
    $readyStmt->close();

    $paymentsStmt = $conn->prepare(
        "SELECT p.id, p.order_id, p.session_id, p.amount, p.method, p.staff_id, p.created_at
         FROM payments p
         INNER JOIN dining_sessions ds ON ds.id = p.session_id
         WHERE p.tenant_id = ? AND p.status = 'Completed' AND ds.tenant_id = p.tenant_id
           AND ds.status = 'Settled' AND p.created_at >= ? AND p.created_at < ?
         ORDER BY p.created_at DESC, p.id DESC"
    );
    $paymentsStmt->bind_param('sss', $tenantId, $from, $toExclusive);
    $paymentsStmt->execute();
    $paymentsResult = $paymentsStmt->get_result();
    $paymentRows = [];
    $grossPaymentsCents = 0;
    $paymentCount = 0;
    $methodGrossCents = [];
    while ($payment = $paymentsResult->fetch_assoc()) {
        $amountCents = (int)round((float)$payment['amount'] * 100);
        $grossPaymentsCents += $amountCents;
        $paymentCount++;
        $method = (string)$payment['method'];
        $methodGrossCents[$method] = ($methodGrossCents[$method] ?? 0) + $amountCents;
        $paymentRows[] = [
            'type' => 'payment',
            'id' => (int)$payment['id'],
            'order_id' => $payment['order_id'] === null ? null : (int)$payment['order_id'],
            'session_id' => $payment['session_id'] === null ? null : (int)$payment['session_id'],
            'amount' => number_format($amountCents / 100, 2, '.', ''),
            'method' => $method,
            'staff_id' => (int)$payment['staff_id'],
            'created_at' => (string)$payment['created_at']
        ];
    }
    $paymentsStmt->close();

    $refundStmt = $conn->prepare(
        "SELECT r.id, r.payment_id, r.amount, r.reason, r.staff_id, r.refunded_at, p.method
         FROM refunds r
         INNER JOIN payments p ON p.id = r.payment_id
         INNER JOIN dining_sessions ds ON ds.id = p.session_id
         WHERE p.tenant_id = ? AND p.status = 'Completed'
           AND ds.tenant_id = p.tenant_id AND ds.status = 'Settled'
           AND r.refunded_at >= ? AND r.refunded_at < ?
         ORDER BY r.refunded_at DESC, r.id DESC"
    );
    $refundStmt->bind_param('sss', $tenantId, $from, $toExclusive);
    $refundStmt->execute();
    $refundResult = $refundStmt->get_result();
    $refundCents = 0;
    $refundCount = 0;
    $methodRefundCents = [];
    while ($refund = $refundResult->fetch_assoc()) {
        $amountCents = (int)round((float)$refund['amount'] * 100);
        $refundCents += $amountCents;
        $refundCount++;
        $method = (string)$refund['method'];
        $methodRefundCents[$method] = ($methodRefundCents[$method] ?? 0) + $amountCents;
        $paymentRows[] = [
            'type' => 'refund',
            'id' => (int)$refund['id'],
            'payment_id' => (int)$refund['payment_id'],
            'amount' => number_format(-$amountCents / 100, 2, '.', ''),
            'method' => $method,
            'reason' => (string)$refund['reason'],
            'staff_id' => (int)$refund['staff_id'],
            'created_at' => (string)$refund['refunded_at']
        ];
    }
    $refundStmt->close();

    $methodTotals = [];
    foreach ($methodGrossCents as $method => $grossCents) {
        $methodRefund = $methodRefundCents[$method] ?? 0;
        $methodTotals[] = [
            'method' => $method,
            'payment_count' => 0,
            'gross_amount' => number_format($grossCents / 100, 2, '.', ''),
            'refund_amount' => number_format($methodRefund / 100, 2, '.', ''),
            'net_amount' => number_format(($grossCents - $methodRefund) / 100, 2, '.', '')
        ];
    }
    foreach ($methodRefundCents as $method => $refundAmount) {
        if (!isset($methodGrossCents[$method])) {
            $methodTotals[] = [
                'method' => $method,
                'payment_count' => 0,
                'gross_amount' => '0.00',
                'refund_amount' => number_format($refundAmount / 100, 2, '.', ''),
                'net_amount' => number_format(-$refundAmount / 100, 2, '.', '')
            ];
        }
    }
    foreach ($methodTotals as &$methodTotal) {
        $methodName = $methodTotal['method'];
        $countStmt = $conn->prepare(
            "SELECT COUNT(*) AS payment_count FROM payments p
             INNER JOIN dining_sessions ds ON ds.id = p.session_id
             WHERE p.tenant_id = ? AND p.status = 'Completed' AND ds.tenant_id = p.tenant_id
               AND ds.status = 'Settled' AND p.method = ? AND p.created_at >= ? AND p.created_at < ?"
        );
        $countStmt->bind_param('ssss', $tenantId, $methodName, $from, $toExclusive);
        $countStmt->execute();
        $methodTotal['payment_count'] = (int)$countStmt->get_result()->fetch_assoc()['payment_count'];
        $countStmt->close();
    }
    unset($methodTotal);

    $placedCount = (int)$placed['order_count'];
    $paidOrderCount = (int)$paidOrders['order_count'];
    $openOrderCount = (int)$openOrders['order_count'];
    $placedSubtotalCents = (int)round((float)$placed['order_subtotal'] * 100);
    $coveredSubtotalCents =
        (int)round((float)$paidOrders['order_subtotal'] * 100) +
        (int)round((float)$openOrders['order_subtotal'] * 100);
    $countVariance = $placedCount - $paidOrderCount - $openOrderCount;
    $subtotalVarianceCents = $placedSubtotalCents - $coveredSubtotalCents;
    $netPaymentsCents = $grossPaymentsCents - $refundCents;
    $warning = $readySessions > 0 ||
        $countVariance !== 0 ||
        abs($subtotalVarianceCents) > 1;
    $warningReason = $readySessions > 0
        ? 'One or more sessions are ReadyForBilling and still require settlement.'
        : (($countVariance !== 0 || abs($subtotalVarianceCents) > 1)
            ? 'Order counts or subtotals do not reconcile within the stated tolerance.'
            : 'No ReadyForBilling sessions or material count/subtotal discrepancies were found.');
    $transactions = $paymentRows;
    usort($transactions, function ($left, $right) {
        return strcmp($right['created_at'], $left['created_at']);
    });

    billingRespond(200, [
        'status' => 'success',
        'from' => $from,
        'to' => $to,
        'summary' => [
            'orders_placed_count' => $placedCount,
            'orders_placed_subtotal' => number_format($placedSubtotalCents / 100, 2, '.', ''),
            'ready_for_billing_sessions' => $readySessions,
            'payments_recorded_count' => $paymentCount,
            'payments_gross_total' => number_format($grossPaymentsCents / 100, 2, '.', ''),
            'refunds_issued_count' => $refundCount,
            'refunds_total' => number_format($refundCents / 100, 2, '.', ''),
            'payments_net_total' => number_format($netPaymentsCents / 100, 2, '.', ''),
            'payment_methods' => $methodTotals
        ],
        'reconciliation' => [
            'warning' => $warning,
            'warning_reason' => $warningReason,
            'orders_placed_count' => $placedCount,
            'paid_orders_count' => $paidOrderCount,
            'open_session_orders_count' => $openOrderCount,
            'count_variance' => $countVariance,
            'orders_placed_subtotal' => number_format($placedSubtotalCents / 100, 2, '.', ''),
            'paid_orders_subtotal' => number_format(((int)round((float)$paidOrders['order_subtotal'] * 100)) / 100, 2, '.', ''),
            'open_session_subtotal' => number_format(((int)round((float)$openOrders['order_subtotal'] * 100)) / 100, 2, '.', ''),
            'subtotal_variance' => number_format($subtotalVarianceCents / 100, 2, '.', ''),
            'balance_check_logic' => 'Orders placed excludes Voided orders and is grouped by order creation date. Paid order coverage requires a Completed payment linked to an order and a Settled dining session; open coverage includes non-settled orders in Open or ReadyForBilling sessions. Count variance = orders placed - paid orders - open-session orders. Subtotal variance compares stored order subtotals for those same populations, with a 0.01 currency-unit tolerance. Payment amounts include server-calculated tax/service and are reported separately net of refunds, so gross/net payment amounts are not compared directly to pre-tax order subtotals. ReadyForBilling session count is a current-status snapshot filtered by dining_sessions.last_modified within the requested date range. The warning is raised for any ReadyForBilling session as well as a nonzero count variance or subtotal variance above 0.01.'
        ],
        'transactions' => $transactions
    ]);
} catch (Throwable $error) {
    error_log('Financial report failed: ' . $error->getMessage());
    billingRespond(500, ['status' => 'error', 'message' => 'Could not load the financial report']);
}
?>
