<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once 'db_config.php';

$tenant_id = $_GET['tenant_id'];
$month = date('Y-m');

try {
    // 1. Sales from orders table
    $sales_stmt = $conn->prepare("SELECT SUM(total_amount) as total FROM orders WHERE tenant_id = :tid AND created_at LIKE :month AND status != 'Cancel'");
    $sales_stmt->execute(['tid' => $tenant_id, 'month' => "$month%"]);
    $sales_data = $sales_stmt->fetch(PDO::FETCH_ASSOC);
    $total_sales = (float)($sales_data['total'] ?? 0);

    // 2. Total Expenses
    $exp_stmt = $conn->prepare("SELECT SUM(amount) as total FROM expenses_v3 WHERE tenant_id = :tid AND date LIKE :month");
    $exp_stmt->execute(['tid' => $tenant_id, 'month' => "$month%"]);
    $exp_data = $exp_stmt->fetch(PDO::FETCH_ASSOC);
    $total_expense = (float)($exp_data['total'] ?? 0);

    // 3. Category Breakout
    $cat_stmt = $conn->prepare("SELECT category as id, SUM(amount) as amount FROM expenses_v3 WHERE tenant_id = :tid AND date LIKE :month GROUP BY category");
    $cat_stmt->execute(['tid' => $tenant_id, 'month' => "$month%"]);
    $categories = $cat_stmt->fetchAll(PDO::FETCH_ASSOC);

    // 4. Vendor Count
    $v_stmt = $conn->prepare("SELECT COUNT(*) as count FROM vendors WHERE tenant_id = :tid");
    $v_stmt->execute(['tid' => $tenant_id]);
    $v_data = $v_stmt->fetch(PDO::FETCH_ASSOC);

    echo json_encode([
        "status" => "success",
        "total_sales" => $total_sales,
        "stats" => [
            "total_expense" => $total_expense,
            "vendor_count" => (int)($v_data['count'] ?? 0),
            "pending_dues" => 0
        ],
        "categories" => $categories
    ]);

} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}
?>
