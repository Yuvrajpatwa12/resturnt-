# Stock Reporting Backend Scripts

Upload these 3 files to your `/public_html/saas_api/` directory on Hostinger.

### 1. `report_stock_out.php`
```php
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

include 'db_config.php';
$data = json_decode(file_get_contents("php://input"), true);

if (!$data || !isset($data['tenant_id']) || empty($data['item_name'])) {
    echo json_encode(["status" => "error", "message" => "Missing item data"]);
    exit;
}

$tenant_id = mysqli_real_escape_string($conn, $data['tenant_id']);
$item_name = mysqli_real_escape_string($conn, $data['item_name']);
$reported_by = mysqli_real_escape_string($conn, $data['reported_by'] ?? 'Kitchen');

$query = "INSERT INTO stock_reports (tenant_id, item_name, reported_by, status)
          VALUES ('$tenant_id', '$item_name', '$reported_by', 'Out of Stock')";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Alert sent to Admin"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}
mysqli_close($conn);
?>
```

### 2. `get_stock_reports.php`
```php
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Content-Type: application/json");

include 'db_config.php';

$tenant_id = mysqli_real_escape_string($conn, $_GET['tenant_id']);

$query = "SELECT * FROM stock_reports
          WHERE tenant_id = '$tenant_id' AND status = 'Out of Stock'
          ORDER BY created_at DESC";
$result = mysqli_query($conn, $query);

$reports = [];
while ($row = mysqli_fetch_assoc($result)) {
    $reports[] = $row;
}

echo json_encode(["status" => "success", "data" => $reports]);
mysqli_close($conn);
?>
```

### 3. `update_stock_report.php`
```php
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

include 'db_config.php';
$data = json_decode(file_get_contents("php://input"), true);

$report_id = mysqli_real_escape_string($conn, $data['report_id']);
$status = mysqli_real_escape_string($conn, $data['status']);

$query = "UPDATE stock_reports SET status = '$status' WHERE id = '$report_id'";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Status updated"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}
mysqli_close($conn);
?>
```
