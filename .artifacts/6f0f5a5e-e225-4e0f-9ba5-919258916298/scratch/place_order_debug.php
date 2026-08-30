<?php
/**
 * place_order.php - Final Debugged Version
 * Ensures orders are saved and persistence is possible.
 */
require_once 'db_config.php';

$data = json_decode(file_get_contents("php://input"));

if (!$data) {
    echo json_encode(["status" => "error", "message" => "Invalid data format received."]);
    exit();
}

if (!empty($data->tenant_id) && !empty($data->table_number) && !empty($data->items)) {
    try {
        $conn->beginTransaction();

        // 1. Resolve Table ID (Auto-create if missing for this tenant)
        $t_stmt = $conn->prepare("SELECT id FROM restaurant_tables WHERE tenant_id = :tid AND table_number = :tnum LIMIT 1");
        $t_stmt->execute(['tid' => $data->tenant_id, 'tnum' => $data->table_number]);

        if ($t_stmt->rowCount() > 0) {
            $table_id = $t_stmt->fetch(PDO::FETCH_ASSOC)['id'];
        } else {
            $ins_t = $conn->prepare("INSERT INTO restaurant_tables (tenant_id, table_number, status) VALUES (:tid, :tnum, 'Dining')");
            $ins_t->execute(['tid' => $data->tenant_id, 'tnum' => $data->table_number]);
            $table_id = $conn->lastInsertId();
        }

        // 2. Create the Order Record
        $stmt = $conn->prepare("INSERT INTO orders (tenant_id, table_id, total_amount, status) VALUES (:tid, :tab, :total, 'Pending')");
        $stmt->execute([
            'tid' => $data->tenant_id,
            'tab' => $table_id,
            'total' => $data->total_amount
        ]);
        $order_id = $conn->lastInsertId();

        // 3. Insert Items into order_items
        foreach($data->items as $item) {
            // Find product ID by name for the specific restaurant
            $p_stmt = $conn->prepare("SELECT id FROM products WHERE tenant_id = :tid AND title = :name LIMIT 1");
            $p_stmt->execute(['tid' => $data->tenant_id, 'name' => $item->name]);
            $product_id = ($p_stmt->rowCount() > 0) ? $p_stmt->fetch(PDO::FETCH_ASSOC)['id'] : 0;

            $ins_i = $conn->prepare("INSERT INTO order_items (order_id, product_id, product_name, quantity, price_at_order) VALUES (:oid, :pid, :pname, :qty, :prc)");
            $ins_i->execute([
                'oid' => $order_id,
                'pid' => $product_id,
                'pname' => $item->name,
                'qty' => $item->quantity,
                'prc' => $item->price
            ]);
        }

        $conn->commit();

        // CRITICAL: Return the order_id so Flutter can save it for refresh
        echo json_encode([
            "status" => "success",
            "message" => "Order #$order_id placed successfully!",
            "order_id" => $order_id
        ]);

    } catch(PDOException $e) {
        $conn->rollBack();
        echo json_encode(["status" => "error", "message" => "Database failure: " . $e->getMessage()]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Missing tenant_id, table_number, or items list."]);
}
?>
