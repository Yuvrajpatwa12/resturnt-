<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_config.php';

$tenant_id = $_GET['tenant_id'];
$month = date('Y-m');

$summary = $conn->query("SELECT
    SUM(CASE WHEN is_income = 1 THEN amount ELSE -amount END) as balance,
    SUM(CASE WHEN is_income = 0 THEN amount ELSE 0 END) as total_expense
    FROM expenses_v2
    WHERE tenant_id = '$tenant_id' AND date LIKE '$month%'
")->fetch_assoc();

$categories = $conn->query("SELECT category, SUM(amount) as amount
    FROM expenses_v2
    WHERE tenant_id = '$tenant_id' AND is_income = 0 AND date LIKE '$month%'
    GROUP BY category
");

$cat_data = [];
while($row = $categories->fetch_assoc()) {
    $cat_data[] = [
        "label" => $row['category'],
        "amount" => (float)$row['amount'],
        "percent" => $summary['total_expense'] > 0 ? (float)$row['amount'] / $summary['total_expense'] : 0
    ];
}

echo json_encode([
    "balance" => (float)($summary['balance'] ?? 0),
    "monthly_budget" => 20000, // Default budget
    "remaining" => 20000 - (float)($summary['total_expense'] ?? 0),
    "categories" => $cat_data
]);

$conn->close();
?>
