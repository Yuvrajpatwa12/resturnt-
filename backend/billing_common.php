<?php
function billingRespond($statusCode, $payload) {
    http_response_code($statusCode);
    header('Content-Type: application/json; charset=UTF-8');
    echo json_encode($payload);
    exit;
}

class BillingConfigurationException extends RuntimeException {}

function billingEnsureSchema($conn) {
    $conn->query("CREATE TABLE IF NOT EXISTS dining_sessions (
        id BIGINT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(100) NOT NULL,
        table_id INT DEFAULT NULL,
        table_number INT NOT NULL,
        status VARCHAR(32) NOT NULL DEFAULT 'Open',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_modified TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_dining_sessions_table (tenant_id, table_id, id),
        INDEX idx_dining_sessions_number (tenant_id, table_number, id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

    foreach ([
        'table_id' => 'INT DEFAULT NULL',
        'last_modified' => 'TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
    ] as $column => $definition) {
        $check = $conn->query("SHOW COLUMNS FROM dining_sessions LIKE '" . $conn->real_escape_string($column) . "'");
        if ($check->num_rows === 0) {
            $conn->query("ALTER TABLE dining_sessions ADD COLUMN `$column` $definition");
        }
    }

    $ordersTable = $conn->query("SHOW TABLES LIKE 'orders'");
    if ($ordersTable->num_rows > 0) {
        $sessionColumn = $conn->query("SHOW COLUMNS FROM orders LIKE 'session_id'");
        if ($sessionColumn->num_rows === 0) {
            $conn->query("ALTER TABLE orders ADD COLUMN session_id BIGINT DEFAULT NULL");
        }
    }

    $statusColumn = $conn->query("SHOW COLUMNS FROM dining_sessions LIKE 'status'")->fetch_assoc();
    if (!$statusColumn) {
        $conn->query("ALTER TABLE dining_sessions ADD COLUMN status VARCHAR(32) NOT NULL DEFAULT 'Open'");
    } elseif (stripos((string)$statusColumn['Type'], 'varchar') !== 0 ||
        (int)preg_replace('/\D+/', '', (string)$statusColumn['Type']) < 16) {
        $conn->query("ALTER TABLE dining_sessions MODIFY COLUMN status VARCHAR(32) NOT NULL DEFAULT 'Open'");
    }

    $conn->query("CREATE TABLE IF NOT EXISTS tenant_settings (
        tenant_id VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL PRIMARY KEY,
        vat_percentage DECIMAL(6,3) NOT NULL,
        service_charge DECIMAL(6,3) NOT NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");
    foreach (['vat_percentage', 'service_charge'] as $rateColumn) {
        $column = $conn->query(
            "SHOW COLUMNS FROM tenant_settings LIKE '$rateColumn'"
        )->fetch_assoc();
        if (!$column) {
            $conn->query(
                "ALTER TABLE tenant_settings ADD COLUMN `$rateColumn` DECIMAL(6,3) NULL"
            );
        } elseif (
            strtolower((string)$column['Type']) !== 'decimal(6,3)' ||
            (string)$column['Null'] !== 'YES' ||
            $column['Default'] !== null
        ) {
            $conn->query(
                "ALTER TABLE tenant_settings MODIFY COLUMN `$rateColumn` DECIMAL(6,3) NULL"
            );
        }
    }
    $legacyBillingSettings = $conn->query("SHOW TABLES LIKE 'tenant_billing_settings'");
    if ($legacyBillingSettings->num_rows > 0) {
        $conn->query("INSERT IGNORE INTO tenant_settings
            (tenant_id, vat_percentage, service_charge)
            SELECT tenant_id, vat_percentage, service_charge
            FROM tenant_billing_settings");
        $conn->query("UPDATE tenant_settings settings
            INNER JOIN tenant_billing_settings legacy
                ON legacy.tenant_id COLLATE utf8mb4_general_ci =
                   settings.tenant_id COLLATE utf8mb4_general_ci
            SET settings.vat_percentage = COALESCE(
                    settings.vat_percentage, legacy.vat_percentage
                ),
                settings.service_charge = COALESCE(
                    settings.service_charge, legacy.service_charge
                )");
    }

    $paymentItemsExists = $conn->query("SHOW TABLES LIKE 'payment_order_items'");
    $backfillPaymentItems = $paymentItemsExists->num_rows === 0;
    $conn->query("CREATE TABLE IF NOT EXISTS payment_order_items (
        payment_id BIGINT NOT NULL,
        order_item_id INT NOT NULL,
        PRIMARY KEY (payment_id, order_item_id),
        UNIQUE KEY uniq_payment_order_item (order_item_id),
        INDEX idx_payment_order_items_item (order_item_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

    $itemsTable = $conn->query("SHOW TABLES LIKE 'order_items'");
    if ($itemsTable->num_rows > 0) {
        $statusColumn = $conn->query("SHOW COLUMNS FROM order_items LIKE 'status'");
        if ($statusColumn->num_rows === 0) {
            $conn->query("ALTER TABLE order_items ADD COLUMN status VARCHAR(32) NOT NULL DEFAULT 'Pending'");
            $backfillPaymentItems = true;
            $conn->query("UPDATE order_items oi
                INNER JOIN orders o ON o.id = oi.order_id
                SET oi.status = CASE
                    WHEN LOWER(o.status) IN ('completed', 'served') THEN 'Completed'
                    WHEN LOWER(o.status) IN ('cancelled', 'canceled') THEN 'Cancelled'
                    WHEN LOWER(o.status) = 'preparing' THEN 'Preparing'
                    WHEN LOWER(o.status) = 'ready' THEN 'Ready'
                    ELSE 'Pending'
                END");
        }

    }

    if ($backfillPaymentItems) {
        $paymentsTable = $conn->query("SHOW TABLES LIKE 'payments'");
        if ($paymentsTable->num_rows > 0 && $itemsTable->num_rows > 0) {
            $paymentOrdersTable = $conn->query("SHOW TABLES LIKE 'payment_orders'");
            $orderLinkMatch = $paymentOrdersTable->num_rows > 0
                ? ' OR EXISTS (SELECT 1 FROM payment_orders po WHERE po.payment_id = p.id AND po.order_id = o.id)'
                : '';
            $conn->query("INSERT IGNORE INTO payment_order_items (payment_id, order_item_id)
                SELECT MIN(p.id), oi.id
                FROM order_items oi
                INNER JOIN orders o ON o.id = oi.order_id
                INNER JOIN payments p
                  ON p.tenant_id COLLATE utf8mb4_general_ci =
                     o.tenant_id COLLATE utf8mb4_general_ci
                 AND p.status = 'Completed'
                 AND ((p.session_id IS NOT NULL AND p.session_id = o.session_id)
                      OR p.order_id = o.id$orderLinkMatch)
                GROUP BY oi.id");
        }
    }
}

function billingGetRates($conn, $tenantId) {
    $stmt = $conn->prepare('SELECT vat_percentage, service_charge
        FROM tenant_settings
        WHERE tenant_id COLLATE utf8mb4_general_ci =
              ? COLLATE utf8mb4_general_ci
        LIMIT 1');
    $stmt->bind_param('s', $tenantId);
    $stmt->execute();
    $rates = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$rates ||
        $rates['vat_percentage'] === null ||
        $rates['service_charge'] === null) {
        throw new BillingConfigurationException(
            'VAT and service charge must be configured for this restaurant before billing'
        );
    }
    $vatPercentage = (float)$rates['vat_percentage'];
    $serviceCharge = (float)$rates['service_charge'];
    if (!is_finite($vatPercentage) || !is_finite($serviceCharge) ||
        $vatPercentage < 0 || $vatPercentage > 100 ||
        $serviceCharge < 0 || $serviceCharge > 100) {
        throw new BillingConfigurationException(
            'Configured VAT and service charge must each be between 0 and 100'
        );
    }
    return [
        'vat_percentage' => $vatPercentage,
        'service_charge' => $serviceCharge,
    ];
}

function billingRateCents($baseCents, $rate) {
    return (int)round($baseCents * $rate / 100, 0, PHP_ROUND_HALF_UP);
}

function billingCalculateBill($conn, $tenantId, $orderIds, $rates = null, $lockRows = false) {
    if ($rates === null) {
        $rates = billingGetRates($conn, $tenantId);
    }
    if (!$orderIds) {
        return [
            'subtotal' => '0.00',
            'tax' => '0.00',
            'service_charge' => '0.00',
            'grand_total' => '0.00',
            'items' => [],
            'unbilled_items' => [],
            'previously_billed_items' => [],
            'rates' => $rates,
        ];
    }

    $orderIds = array_values(array_unique(array_map('intval', $orderIds)));
    $placeholders = implode(',', array_fill(0, count($orderIds), '?'));
    $lockClause = $lockRows ? ' FOR UPDATE' : '';
    $stmt = $conn->prepare("SELECT oi.id, oi.order_id, oi.product_id, oi.product_name,
            oi.quantity, oi.price_at_order, oi.status,
            CASE WHEN poi.order_item_id IS NULL THEN 0 ELSE 1 END AS is_billed
        FROM order_items oi
        INNER JOIN orders o ON o.id = oi.order_id
        LEFT JOIN payment_order_items poi ON poi.order_item_id = oi.id
        WHERE o.tenant_id = ? AND oi.order_id IN ($placeholders)
        ORDER BY oi.order_id, oi.id$lockClause");
    $types = 's' . str_repeat('i', count($orderIds));
    $params = array_merge([$tenantId], $orderIds);
    $bindings = [$types];
    foreach ($params as $index => &$value) {
        $bindings[] = &$value;
    }
    call_user_func_array([$stmt, 'bind_param'], $bindings);
    $stmt->execute();
    $result = $stmt->get_result();

    $items = [];
    $unbilledItems = [];
    $previouslyBilledItems = [];
    $subtotalCents = 0;
    while ($row = $result->fetch_assoc()) {
        $quantity = max(0, (int)$row['quantity']);
        $unitCents = (int)round((float)$row['price_at_order'] * 100, 0, PHP_ROUND_HALF_UP);
        $status = trim((string)($row['status'] ?? 'Pending'));
        $lineCents = $unitCents * $quantity;
        $item = [
            'id' => (int)$row['id'],
            'order_id' => (int)$row['order_id'],
            'product_id' => (int)$row['product_id'],
            'product_name' => (string)$row['product_name'],
            'quantity' => $quantity,
            'price_at_order' => number_format($unitCents / 100, 2, '.', ''),
            'status' => $status,
        ];
        if ((int)$row['is_billed'] === 1) {
            $item['billing_status'] = 'Billed';
            $item['financial_contribution'] = '0.00';
            $item['line_total'] = number_format($lineCents / 100, 2, '.', '');
            $previouslyBilledItems[] = $item;
        } elseif (in_array(strtolower($status), ['served', 'completed'], true)) {
            $subtotalCents += $lineCents;
            $item['billing_status'] = 'Unbilled';
            $item['financial_contribution'] = number_format($lineCents / 100, 2, '.', '');
            $item['line_total'] = number_format($lineCents / 100, 2, '.', '');
            $items[] = $item;
        } else {
            $item['billing_status'] = 'Unbilled';
            $item['financial_contribution'] = '0.00';
            $item['line_total'] = '0.00';
            $unbilledItems[] = $item;
        }
    }
    $stmt->close();

    $serviceCents = billingRateCents($subtotalCents, $rates['service_charge']);
    $taxCents = billingRateCents($subtotalCents + $serviceCents, $rates['vat_percentage']);
    $grandCents = $subtotalCents + $serviceCents + $taxCents;
    return [
        'subtotal' => number_format($subtotalCents / 100, 2, '.', ''),
        'tax' => number_format($taxCents / 100, 2, '.', ''),
        'service_charge' => number_format($serviceCents / 100, 2, '.', ''),
        'grand_total' => number_format($grandCents / 100, 2, '.', ''),
        'items' => $items,
        'unbilled_items' => $unbilledItems,
        'previously_billed_items' => $previouslyBilledItems,
        'rates' => $rates,
    ];
}

function billingAuthTenant($conn, $allowedRoles) {
    if (!function_exists('requireAuth')) {
        billingRespond(500, ['status' => 'error', 'message' => 'Staff authentication is not configured']);
    }
    $auth = requireAuth($conn, $allowedRoles);
    $user = isset($auth['user']) && is_array($auth['user']) ? $auth['user'] : [];
    $tenantId = trim((string)($user['tenant_id'] ?? ''));
    if ($tenantId === '') {
        billingRespond(401, ['status' => 'error', 'message' => 'Authenticated staff tenant is missing']);
    }
    return $user;
}
?>
