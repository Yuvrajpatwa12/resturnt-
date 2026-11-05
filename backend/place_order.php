<?php
/**
 * place_order.php - Final Ultra-Robust Production Version with FCM Push Notifications
 */

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';
require_once __DIR__ . '/billing_common.php';
require_once 'push_notifier.php';
require_once 'email_notification_common.php';

if ($conn->connect_error) {
    echo json_encode(["status" => "error", "message" => "DB Connection Failed"]);
    exit;
}

$json = file_get_contents('php://input');
$data = json_decode($json);

$tenant_id = (!empty($data->tenant_id)) ? (string)$data->tenant_id : 'startups_main';
$table_number = isset($data->table_number) ? (int)$data->table_number : 0;
$user_id = (!empty($data->user_id)) ? (string)$data->user_id : 'guest';
$customer_email = (!empty($data->customer_email)) ? (string)$data->customer_email : '';
$idempotency_key = trim((string)($data->idempotency_key ?? ''));
$submittedItems = $data->items ?? null;

function placeOrderProductColumns($conn) {
    $result = $conn->query("SHOW COLUMNS FROM products");
    $available = [];
    while ($column = $result->fetch_assoc()) {
        $available[strtolower($column['Field'])] = $column['Field'];
    }
    $title = $available['title'] ?? $available['name'] ?? null;
    $price = $available['price'] ?? $available['selling_price'] ?? null;
    $active = $available['is_available'] ?? $available['is_active'] ?? $available['status'] ?? null;
    if (!$title || !$price || !isset($available['tenant_id']) || !$active) {
        throw new RuntimeException("Products must have tenant_id, title, price and an active-status column");
    }
    return [$title, $price, $active, $available['variants'] ?? null];
}

function placeOrderGetProduct($conn, $tenantId, $item, $columns) {
    [$titleColumn, $priceColumn, $activeColumn, $variantsColumn] = $columns;
    $productId = (int)($item->product_id ?? $item->id ?? 0);
    $productName = trim((string)($item->name ?? $item->product_name ?? ''));
    $variantName = trim((string)($item->variant_name ?? ''));
    $variantSelect = $variantsColumn ? "`$variantsColumn`" : "NULL";
    if ($productId > 0) {
        $stmt = $conn->prepare("SELECT id, `$titleColumn` AS title, `$priceColumn` AS price, `$activeColumn` AS active, $variantSelect AS variants
            FROM products WHERE tenant_id = ? AND id = ? LIMIT 1");
        $stmt->bind_param("si", $tenantId, $productId);
    } elseif ($productName !== '') {
        $stmt = $conn->prepare("SELECT id, `$titleColumn` AS title, `$priceColumn` AS price, `$activeColumn` AS active, $variantSelect AS variants
            FROM products WHERE tenant_id = ? AND `$titleColumn` = ? LIMIT 2");
        $stmt->bind_param("ss", $tenantId, $productName);
    } else {
        throw new InvalidArgumentException("Every order item must identify a product");
    }
    $stmt->execute();
    $result = $stmt->get_result();
    $product = $result->fetch_assoc();
    $ambiguous = $result->num_rows > 1;
    $stmt->close();
    if (!$product || $ambiguous) {
        throw new InvalidArgumentException($ambiguous
            ? "Product name is ambiguous; submit its product_id"
            : "A submitted product was not found for this restaurant");
    }
    $active = $product['active'];
    if (strtolower($activeColumn) === 'status') {
        if (!in_array(strtolower(trim((string)$active)), ['active', 'available', '1'], true)) {
            throw new InvalidArgumentException("Product " . $product['title'] . " is not available");
        }
    } elseif (!in_array((string)$active, ['1', 'true'], true)) {
        throw new InvalidArgumentException("Product " . $product['title'] . " is not available");
    }
    $baseTitle = (string)$product['title'];
    $priceValue = $product['price'];
    if ($variantName !== '') {
        $variants = json_decode((string)$product['variants'], true);
        $matchingVariant = null;
        if (is_array($variants)) {
            foreach ($variants as $variant) {
                if (is_array($variant) &&
                    strcasecmp(trim((string)($variant['name'] ?? '')), $variantName) === 0) {
                    $matchingVariant = $variant;
                    break;
                }
            }
        }
        if (!$matchingVariant || !isset($matchingVariant['price']) || !is_numeric($matchingVariant['price'])) {
            throw new InvalidArgumentException("The selected product variant is unavailable");
        }
        $priceValue = $matchingVariant['price'];
        $baseTitle .= " (" . $variantName . ")";
    }
    $priceCents = (int)round((float)$priceValue * 100, 0, PHP_ROUND_HALF_UP);
    if ($priceCents < 0) {
        throw new InvalidArgumentException("Product price is invalid");
    }
    return [
        'id' => (int)$product['id'],
        'title' => $baseTitle,
        'price_cents' => $priceCents,
    ];
}

function placeOrderStoredItems($conn, $orderId) {
    $stmt = $conn->prepare("SELECT product_id, product_name, quantity, price_at_order AS price
        FROM order_items WHERE order_id = ? ORDER BY id");
    $stmt->bind_param("i", $orderId);
    $stmt->execute();
    $items = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    return $items;
}

try {
    billingEnsureSchema($conn);
    try {
        @mysqli_query($conn, "CREATE TABLE IF NOT EXISTS orders (
            id INT AUTO_INCREMENT PRIMARY KEY,
            tenant_id VARCHAR(100) NOT NULL,
            table_id INT DEFAULT NULL,
            user_id VARCHAR(100) DEFAULT '',
            customer_email VARCHAR(255) DEFAULT '',
            total_amount DECIMAL(10,2) DEFAULT 0.00,
            status VARCHAR(50) DEFAULT 'Pending',
            session_id INT DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )");
    } catch (Throwable $e) {}

    try {
        @mysqli_query($conn, "CREATE TABLE IF NOT EXISTS order_items (
            id INT AUTO_INCREMENT PRIMARY KEY,
            order_id INT NOT NULL,
            product_id INT DEFAULT 0,
            product_name VARCHAR(255) NOT NULL,
            quantity INT DEFAULT 1,
            notes TEXT DEFAULT NULL,
            price_at_order DECIMAL(10,2) DEFAULT 0.00,
            status VARCHAR(32) NOT NULL DEFAULT 'Pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )");
    } catch (Throwable $e) {}

    try { @mysqli_query($conn, "ALTER TABLE orders ADD COLUMN customer_email VARCHAR(255) DEFAULT ''"); } catch (Throwable $e) {}
    try { @mysqli_query($conn, "ALTER TABLE orders ADD COLUMN session_id INT DEFAULT NULL"); } catch (Throwable $e) {}
    try { @mysqli_query($conn, "ALTER TABLE order_items ADD COLUMN product_id INT DEFAULT 0"); } catch (Throwable $e) {}
    $idempotencyColumn = $conn->query("SHOW COLUMNS FROM orders LIKE 'idempotency_key'");
    if ($idempotencyColumn->num_rows === 0) {
        $conn->query("ALTER TABLE orders ADD COLUMN idempotency_key VARCHAR(128) DEFAULT NULL");
    }
    $idempotencyIndex = $conn->query("SHOW INDEX FROM orders WHERE Key_name = 'uniq_orders_tenant_idempotency'");
    if ($idempotencyIndex->num_rows === 0) {
        $conn->query("ALTER TABLE orders ADD UNIQUE KEY uniq_orders_tenant_idempotency (tenant_id, idempotency_key)");
    }
    $tenantOrderNumberColumn = $conn->query(
        "SHOW COLUMNS FROM orders LIKE 'tenant_order_number'"
    );
    if ($tenantOrderNumberColumn->num_rows === 0) {
        $conn->query(
            'ALTER TABLE orders ADD COLUMN tenant_order_number INT UNSIGNED DEFAULT NULL'
        );
    }
    $tenantOrderNumberIndex = $conn->query(
        "SHOW INDEX FROM orders WHERE Key_name = 'uniq_tenant_order_number'"
    );
    if ($tenantOrderNumberIndex->num_rows === 0) {
        $conn->query(
            'ALTER TABLE orders ADD UNIQUE KEY uniq_tenant_order_number (tenant_id, tenant_order_number)'
        );
    }
    $conn->query("CREATE TABLE IF NOT EXISTS tenant_order_counters (
        tenant_id VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci NOT NULL PRIMARY KEY,
        last_number INT UNSIGNED NOT NULL DEFAULT 0,
        initialized TINYINT(1) NOT NULL DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

    if (!preg_match('/^[A-Za-z0-9._~-]{16,128}$/', $idempotency_key)) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "A valid idempotency_key is required for every order submission"]);
        exit;
    }
    if (!is_array($submittedItems) || count($submittedItems) === 0) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "At least one order item is required"]);
        exit;
    }
    if ($table_number <= 0) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "A valid table_number is required"]);
        exit;
    }

    $conn->begin_transaction();

    $counterInsert = $conn->prepare(
        'INSERT IGNORE INTO tenant_order_counters (tenant_id, last_number, initialized)
         VALUES (?, 0, 0)'
    );
    $counterInsert->bind_param('s', $tenant_id);
    $counterInsert->execute();
    $counterInsert->close();

    $counterStmt = $conn->prepare(
        'SELECT last_number, initialized FROM tenant_order_counters
         WHERE tenant_id = ? LIMIT 1 FOR UPDATE'
    );
    $counterStmt->bind_param('s', $tenant_id);
    $counterStmt->execute();
    $counter = $counterStmt->get_result()->fetch_assoc();
    $counterStmt->close();
    if (!$counter) {
        throw new RuntimeException('Could not initialize restaurant order numbering');
    }

    $lastOrderNumber = (int)$counter['last_number'];
    if ((int)$counter['initialized'] !== 1) {
        $legacyOrders = $conn->prepare(
            'SELECT id FROM orders
             WHERE tenant_id = ?
             ORDER BY created_at ASC, id ASC
             FOR UPDATE'
        );
        $legacyOrders->bind_param('s', $tenant_id);
        $legacyOrders->execute();
        $legacyResult = $legacyOrders->get_result();
        $backfillOrder = $conn->prepare(
            'UPDATE orders SET tenant_order_number = ?
             WHERE id = ? AND tenant_id = ?'
        );
        $lastOrderNumber = 0;
        while ($legacyOrder = $legacyResult->fetch_assoc()) {
            $lastOrderNumber++;
            $legacyOrderId = (int)$legacyOrder['id'];
            $backfillOrder->bind_param(
                'iis',
                $lastOrderNumber,
                $legacyOrderId,
                $tenant_id
            );
            $backfillOrder->execute();
        }
        $backfillOrder->close();
        $legacyOrders->close();

        $initializeCounter = $conn->prepare(
            'UPDATE tenant_order_counters
             SET last_number = ?, initialized = 1
             WHERE tenant_id = ?'
        );
        $initializeCounter->bind_param('is', $lastOrderNumber, $tenant_id);
        $initializeCounter->execute();
        $initializeCounter->close();
    }

    $replay = $conn->prepare("SELECT id, total_amount, tenant_order_number FROM orders WHERE tenant_id = ? AND idempotency_key = ? LIMIT 1 FOR UPDATE");
    $replay->bind_param("ss", $tenant_id, $idempotency_key);
    $replay->execute();
    $existingOrder = $replay->get_result()->fetch_assoc();
    $replay->close();
    if ($existingOrder) {
        $conn->commit();
        $existingOrderId = (int)$existingOrder['id'];
        echo json_encode([
            "status" => "success",
            "order_id" => $existingOrderId,
            "order_number" => (int)$existingOrder['tenant_order_number'],
            "total_amount" => $existingOrder['total_amount'],
            "items" => placeOrderStoredItems($conn, $existingOrderId),
            "idempotent_replay" => true,
            "message" => "This order submission was already accepted"
        ]);
        exit;
    }

    // 1. Resolve Table ID
    $t_stmt = $conn->prepare("SELECT id, status FROM restaurant_tables WHERE tenant_id = ? AND table_number = ? LIMIT 1 FOR UPDATE");
    $t_stmt->bind_param("si", $tenant_id, $table_number);
    $t_stmt->execute();
    $t_res = $t_stmt->get_result();

    $table_id = null;
    if ($t_row = $t_res->fetch_assoc()) {
        $table_id = (int)$t_row['id'];
    } else {
        $conn->rollback();
        http_response_code(409);
        echo json_encode([
            "status" => "error",
            "message" => "The selected table does not exist for this restaurant"
        ]);
        exit;
    }

    // A table cannot accept more items after it has been sent to billing.
    $s_stmt = $conn->prepare("SELECT id, status FROM dining_sessions
        WHERE tenant_id = ? AND table_number = ?
          AND LOWER(status) NOT IN ('settled', 'closed')
        ORDER BY id DESC LIMIT 1 FOR UPDATE");
    $s_stmt->bind_param("si", $tenant_id, $table_number);
    $s_stmt->execute();
    $activeSession = $s_stmt->get_result()->fetch_assoc();
    $s_stmt->close();
    $activeSessionStatus = strtolower(trim((string)($activeSession['status'] ?? '')));
    if ($activeSession && !in_array($activeSessionStatus, ['open', 'settled', 'closed'], true)) {
        $conn->rollback();
        http_response_code(409);
        echo json_encode([
            "status" => "error",
            "message" => "This table is " . (string)$activeSession['status'] . " and cannot accept new items. Ask an admin to reopen the session."
        ]);
        exit;
    }
    if ($activeSession && in_array($activeSessionStatus, ['settled', 'closed'], true)) {
        $activeSession = null;
    }

    $productColumns = placeOrderProductColumns($conn);
    $verifiedItems = [];
    $totalCents = 0;
    foreach ($submittedItems as $item) {
        if (!is_object($item)) {
            throw new InvalidArgumentException("Order items must be valid objects");
        }
        $quantity = filter_var($item->quantity ?? null, FILTER_VALIDATE_INT);
        if ($quantity === false || $quantity < 1 || $quantity > 1000) {
            throw new InvalidArgumentException("Each item quantity must be between 1 and 1000");
        }
        $product = placeOrderGetProduct($conn, $tenant_id, $item, $productColumns);
        $totalCents += $product['price_cents'] * $quantity;
        $verifiedItems[] = [
            'product_id' => $product['id'],
            'product_name' => $product['title'],
            'quantity' => $quantity,
            'price' => number_format($product['price_cents'] / 100, 2, '.', ''),
        ];
    }
    $total_amount = number_format($totalCents / 100, 2, '.', '');

    if ($activeSession) {
        $session_id_val = (int)$activeSession['id'];
        $session_update = $conn->prepare("UPDATE dining_sessions SET last_modified = CURRENT_TIMESTAMP WHERE id = ?");
        $session_update->bind_param("i", $session_id_val);
        $session_update->execute();
    } else {
        $session_insert = $conn->prepare("INSERT INTO dining_sessions (tenant_id, table_id, table_number, status)
            VALUES (?, ?, ?, 'Open')");
        $session_insert->bind_param("sii", $tenant_id, $table_id, $table_number);
        $session_insert->execute();
        $session_id_val = (int)$conn->insert_id;
    }
    $attachLegacyOrders = $conn->prepare("UPDATE orders SET session_id = ?
        WHERE tenant_id = ? AND table_id = ? AND (session_id IS NULL OR session_id = 0)
        AND LOWER(status) <> 'settled'");
    $attachLegacyOrders->bind_param("isi", $session_id_val, $tenant_id, $table_id);
    $attachLegacyOrders->execute();

    $table_update = $conn->prepare("UPDATE restaurant_tables SET status = 'Dining' WHERE id = ? AND tenant_id = ?");
    $table_update->bind_param("is", $table_id, $tenant_id);
    $table_update->execute();

    $orderNumber = $lastOrderNumber + 1;
    $advanceCounter = $conn->prepare(
        'UPDATE tenant_order_counters
         SET last_number = ?
         WHERE tenant_id = ?'
    );
    $advanceCounter->bind_param('is', $orderNumber, $tenant_id);
    $advanceCounter->execute();
    $advanceCounter->close();

    // 3. Create Order
    $stmt = $conn->prepare("INSERT INTO orders (tenant_id, table_id, user_id, customer_email, total_amount, status, session_id, idempotency_key, tenant_order_number, created_at) VALUES (?, ?, ?, ?, ?, 'Pending', ?, ?, ?, NOW())");
    $stmt->bind_param("sissdisi", $tenant_id, $table_id, $user_id, $customer_email, $total_amount, $session_id_val, $idempotency_key, $orderNumber);
    $stmt->execute();
    $order_id = (int)$conn->insert_id;
    if ($order_id <= 0) {
        throw new RuntimeException("Order record was not created");
    }

    // 4. Save Items (Matching exact order_items schema: order_id, product_id, product_name, quantity, price_at_order)
    if (!empty($verifiedItems)) {
        $item_ins = $conn->prepare("INSERT INTO order_items
            (order_id, product_id, product_name, quantity, price_at_order, status)
            VALUES (?, ?, ?, ?, ?, 'Pending')");

        foreach ($verifiedItems as $item) {
            $item_pid = $item['product_id'];
            $item_name = $item['product_name'];
            $item_qty = $item['quantity'];
            $item_prc = (float)$item['price'];

            $item_ins->bind_param("iisid", $order_id, $item_pid, $item_name, $item_qty, $item_prc);
            $item_ins->execute();
        }
    }

    $conn->commit();

    // 5. Trigger Order Notification & FCM Push
    $target_uid = !empty($customer_email) ? $customer_email : $user_id;
    if (!empty($target_uid) && $target_uid !== 'guest') {
        try {
            $notif_title = "Order Placed!";
            $notif_msg = "Your Order #$orderNumber has been received and is pending preparation.";

            $notif_ins = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type) VALUES (?, ?, ?, ?, 'order')");
            $notif_ins->bind_param("ssss", $tenant_id, $target_uid, $notif_title, $notif_msg);
            $notif_ins->execute();
            $customerNotificationId = (int)$conn->insert_id;

            // Only queue email if customer_email is provided
            if (!empty($customer_email) && filter_var($customer_email, FILTER_VALIDATE_EMAIL)) {
                // Ensure customer has email preferences
                $pref_check = $conn->prepare("SELECT 1 FROM customer_notification_email_preferences WHERE tenant_id = ? AND email = ? LIMIT 1");
                $pref_check->bind_param("ss", $tenant_id, $customer_email);
                $pref_check->execute();
                if ($pref_check->get_result()->num_rows === 0) {
                    // Create default preferences for this customer
                    $pref_ins = $conn->prepare("INSERT INTO customer_notification_email_preferences (tenant_id, email, email_enabled, email_follow, email_wave, email_message) VALUES (?, ?, 1, 1, 1, 1)");
                    $pref_ins->bind_param("ss", $tenant_id, $customer_email);
                    $pref_ins->execute();
                }
                queueEmailNotification(
                    $conn,
                    $tenant_id,
                    $customer_email,
                    $customerNotificationId,
                    'order'
                );
            }

            notifyUser($target_uid, $tenant_id, $notif_title, $notif_msg, 'order');
        } catch (Throwable $notification_error) {
            error_log("Order #$order_id was saved, but notification delivery failed: " . $notification_error->getMessage());
        }
    }

    // 6. Notify Admin about new order
    try {
        $admin_stmt = $conn->prepare("SELECT contact_email FROM tenants WHERE tenant_id = ? LIMIT 1");
        $admin_stmt->bind_param("s", $tenant_id);
        $admin_stmt->execute();
        $admin_res = $admin_stmt->get_result();
        $admin_email = 'admin';
        if ($admin_row = $admin_res->fetch_assoc()) {
            $admin_email = !empty($admin_row['contact_email'])
                ? $admin_row['contact_email']
                : 'admin';
        }

        $admin_notif_title = "New Order #$orderNumber";
        $admin_notif_msg = "Table #$table_number - Total: ₹$total_amount";
        $admin_notif = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type) VALUES (?, ?, ?, ?, 'order')");
        $admin_notif->bind_param("ssss", $tenant_id, $admin_email, $admin_notif_title, $admin_notif_msg);
        $admin_notif->execute();
        queueEmailNotification($conn, $tenant_id, $admin_email, $conn->insert_id, 'order');
    } catch (Throwable $admin_notification_error) {
        error_log("Order #$order_id was saved, but admin notification failed: " . $admin_notification_error->getMessage());
    }

    // Notify registered waiter and kitchen accounts for this restaurant only.
    try {
        $staffStmt = $conn->prepare(
            "SELECT DISTINCT LOWER(TRIM(email)) AS email
             FROM users
             WHERE tenant_id = ?
               AND LOWER(TRIM(role)) IN ('waiter', 'kitchen')
               AND email IS NOT NULL AND TRIM(email) <> ''"
        );
        $staffStmt->bind_param('s', $tenant_id);
        $staffStmt->execute();
        $staffRecipients = $staffStmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $staffStmt->close();

        $staffTitle = "New Order #$orderNumber";
        $itemSummary = implode(', ', array_map(
            static function ($item) {
                return (int)$item['quantity'] . ' x ' . $item['product_name'];
            },
            $verifiedItems
        ));
        $staffMessage = "Table #$table_number • Total: $total_amount • $itemSummary";
        foreach ($staffRecipients as $recipient) {
            $staffEmail = strtolower(trim((string)$recipient['email']));
            if (!filter_var($staffEmail, FILTER_VALIDATE_EMAIL)) {
                continue;
            }

            try {
                $staffNotification = $conn->prepare(
                    "INSERT INTO notifications
                     (tenant_id, user_id, title, message, type)
                     VALUES (?, ?, ?, ?, 'order')"
                );
                $staffNotification->bind_param(
                    'ssss',
                    $tenant_id,
                    $staffEmail,
                    $staffTitle,
                    $staffMessage
                );
                $staffNotification->execute();
                $staffNotificationId = (int)$conn->insert_id;
                $staffNotification->close();
                queueEmailNotification(
                    $conn,
                    $tenant_id,
                    $staffEmail,
                    $staffNotificationId,
                    'staff_order'
                );
            } catch (Throwable $recipientError) {
                error_log(
                    "Order #$order_id staff notification failed for tenant " .
                    "$tenant_id: " . $recipientError->getMessage()
                );
            }
        }
    } catch (Throwable $staff_notification_error) {
        error_log(
            "Order #$order_id waiter/kitchen notifications failed for tenant " .
            "$tenant_id: " . $staff_notification_error->getMessage()
        );
    }

    echo json_encode([
        "status" => "success",
        "order_id" => (int)$order_id,
        "order_number" => $orderNumber,
        "total_amount" => $total_amount,
        "items" => $verifiedItems,
        "idempotent_replay" => false,
        "message" => "Order placed successfully"
    ]);

} catch (InvalidArgumentException $e) {
    if ($conn) {
        try { $conn->rollback(); } catch (Throwable $rollbackError) {}
    }
    http_response_code(422);
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
} catch (mysqli_sql_exception $e) {
    if ($conn) {
        try { $conn->rollback(); } catch (Throwable $rollbackError) {}
    }
    if ((int)$e->getCode() === 1062 && $idempotency_key !== '') {
        $replay = $conn->prepare("SELECT id, total_amount, tenant_order_number FROM orders WHERE tenant_id = ? AND idempotency_key = ? LIMIT 1");
        $replay->bind_param("ss", $tenant_id, $idempotency_key);
        $replay->execute();
        $existingOrder = $replay->get_result()->fetch_assoc();
        $replay->close();
        if ($existingOrder) {
            $existingOrderId = (int)$existingOrder['id'];
            echo json_encode([
                "status" => "success",
                "order_id" => $existingOrderId,
                "order_number" => (int)($existingOrder['tenant_order_number'] ?? 0),
                "total_amount" => $existingOrder['total_amount'],
                "items" => placeOrderStoredItems($conn, $existingOrderId),
                "idempotent_replay" => true,
                "message" => "This order submission was already accepted"
            ]);
        } else {
            http_response_code(500);
            echo json_encode(["status" => "error", "message" => "Order could not be saved"]);
        }
    } else {
        error_log("Order placement database error: " . $e->getMessage());
        http_response_code(500);
        echo json_encode(["status" => "error", "message" => "Order could not be saved"]);
    }
} catch (Exception $e) {
    if ($conn) {
        try { $conn->rollback(); } catch(Exception $ex) {}
    }
    error_log("Order placement failed: " . $e->getMessage());
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "System Error: " . $e->getMessage()]);
}

if ($conn) {
    $conn->close();
}
?>
