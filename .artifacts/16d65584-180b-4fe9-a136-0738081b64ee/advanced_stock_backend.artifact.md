# Advanced Stock Reporting Backend (v2)

Replace your existing files in `/public_html/saas_api/` with these versions.

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
    echo json_encode(["status" => "error", "message" => "Missing data"]);
    exit;
}

$tenant_id = mysqli_real_escape_string($conn, $data['tenant_id']);
$item_name = mysqli_real_escape_string($conn, $data['item_name']);
$notes = mysqli_real_escape_string($conn, $data['notes'] ?? '');
$urgency = mysqli_real_escape_string($conn, $data['urgency'] ?? 'Medium');
$reported_by = mysqli_real_escape_string($conn, $data['reported_by'] ?? 'Kitchen');

$query = "INSERT INTO stock_reports (tenant_id, item_name, notes, urgency, reported_by, status, is_seen)
          VALUES ('$tenant_id', '$item_name', '$notes', '$urgency', '$reported_by', 'Out of Stock', 0)";

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
$only_unseen = isset($_GET['unseen']) ? 1 : 0;

$query = "SELECT * FROM stock_reports WHERE tenant_id = '$tenant_id'";
if ($only_unseen) {
    $query .= " AND is_seen = 0";
}
$query .= " AND status = 'Out of Stock' ORDER BY created_at DESC";

$result = mysqli_query($conn, $query);
$reports = [];
while ($row = mysqli_fetch_assoc($result)) {
    $reports[] = $row;
}

echo json_encode(["status" => "success", "data" => $reports]);
mysqli_close($conn);
?>
```

### 3. `get_unseen_alert_count.php` [NEW]
```php
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Content-Type: application/json");

include 'db_config.php';

$tenant_id = mysqli_real_escape_string($conn, $_GET['tenant_id']);

$query = "SELECT COUNT(*) as total FROM stock_reports
          WHERE tenant_id = '$tenant_id' AND is_seen = 0 AND status = 'Out of Stock'";
$result = mysqli_query($conn, $query);
$row = mysqli_fetch_assoc($result);

echo json_encode(["status" => "success", "count" => (int)$row['total']]);
mysqli_close($conn);
?>
```

### 4. `mark_alerts_seen.php` [NEW]
```php
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

include 'db_config.php';
$data = json_decode(file_get_contents("php://input"), true);

$tenant_id = mysqli_real_escape_string($conn, $data['tenant_id']);

$query = "UPDATE stock_reports SET is_seen = 1 WHERE tenant_id = '$tenant_id' AND is_seen = 0";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Alerts marked as seen"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}
mysqli_close($conn);
?>
```
