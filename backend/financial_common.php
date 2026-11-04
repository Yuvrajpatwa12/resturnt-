<?php
function financialEnsureSchema($conn) {
    $conn->query("CREATE TABLE IF NOT EXISTS order_voids (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        order_id INT NOT NULL,
        staff_id BIGINT NOT NULL,
        reason TEXT NOT NULL,
        original_amount DECIMAL(12,2) NOT NULL,
        voided_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_order_voids_order (order_id),
        INDEX idx_order_voids_time (voided_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
    $conn->query("CREATE TABLE IF NOT EXISTS refunds (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        payment_id BIGINT NOT NULL,
        amount DECIMAL(12,2) NOT NULL,
        reason TEXT NOT NULL,
        staff_id BIGINT NOT NULL,
        refunded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_refunds_payment (payment_id),
        INDEX idx_refunds_time (refunded_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
    $conn->query("CREATE TABLE IF NOT EXISTS payment_orders (
        payment_id BIGINT NOT NULL,
        order_id INT NOT NULL,
        PRIMARY KEY (payment_id, order_id),
        INDEX idx_payment_orders_order (order_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
}

function financialAmountCents($value) {
    if (!is_scalar($value)) {
        return null;
    }
    $value = trim((string)$value);
    if (!preg_match('/^(\d{1,10})(?:\.(\d{1,2}))?$/', $value, $matches)) {
        return null;
    }
    return ((int)$matches[1] * 100) +
        (int)str_pad($matches[2] ?? '00', 2, '0');
}

function financialAuthUser($conn, $allowedRoles) {
    if (!function_exists('requireAuth')) {
        billingRespond(500, ['status' => 'error', 'message' => 'Staff authentication is not configured']);
    }
    $auth = requireAuth($conn, $allowedRoles);
    $user = isset($auth['user']) && is_array($auth['user']) ? $auth['user'] : [];
    if (trim((string)($user['tenant_id'] ?? '')) === '' ||
        (int)($user['id'] ?? 0) <= 0) {
        billingRespond(401, ['status' => 'error', 'message' => 'Authenticated staff identity is incomplete']);
    }
    return $user;
}
?>
