# Multi-Stage Stock Approval Backend (v3)

Update your files in `/public_html/saas_api/` with these stage-aware versions.

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

// Initial status is now 'Requested'
$query = "INSERT INTO stock_reports (tenant_id, item_name, notes, urgency, reported_by, status, is_seen)
          VALUES ('$tenant_id', '$item_name', '$notes', '$urgency', '$reported_by', 'Requested', 0)";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Request sent to Admin"]);
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

// Fetch both 'Requested' and 'Approved' items. 'Received' items are hidden.
$query = "SELECT * FROM stock_reports
          WHERE tenant_id = '$tenant_id' AND status IN ('Requested', 'Approved')
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

if (!isset($data['report_id']) || !isset($data['status'])) {
    echo json_encode(["status" => "error", "message" => "ID or Status missing"]);
    exit;
}

$report_id = mysqli_real_escape_string($conn, $data['report_id']);
$status = mysqli_real_escape_string($conn, $data['status']);

// Valid statuses: 'Requested', 'Approved', 'Received'
$query = "UPDATE stock_reports SET status = '$status' WHERE id = '$report_id'";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Status updated to $status"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}
mysqli_close($conn);
?>
```
