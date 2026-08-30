# Purchase Return Backend Scripts

Upload these files to your Hostinger server at `/public_html/saas_api/`.

### 1. `add_return.php`
```php
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

include 'db_config.php';

$data = json_decode(file_get_contents("php://input"), true);

if (!$data || !isset($data['tenant_id'])) {
    echo json_encode(["status" => "error", "message" => "Tenant ID missing"]);
    exit;
}

$tenant_id = mysqli_real_escape_string($conn, $data['tenant_id']);
$ingredient_name = mysqli_real_escape_string($conn, $data['ingredient_name']);
$supplier_name = mysqli_real_escape_string($conn, $data['supplier_name']);
$quantity = mysqli_real_escape_string($conn, $data['quantity']);
$unit = mysqli_real_escape_string($conn, $data['unit']);
$return_amount = mysqli_real_escape_string($conn, $data['return_amount']);
$reason = mysqli_real_escape_string($conn, $data['reason']);
$return_date = date("Y-m-d H:i:s");

$query = "INSERT INTO purchases_returns (tenant_id, ingredient_name, supplier_name, quantity, unit, return_amount, reason, return_date)
          VALUES ('$tenant_id', '$ingredient_name', '$supplier_name', '$quantity', '$unit', '$return_amount', '$reason', '$return_date')";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Return recorded"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}

mysqli_close($conn);
?>
```

### 2. `get_returns.php`
```php
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

include 'db_config.php';

$tenant_id = mysqli_real_escape_string($conn, $_GET['tenant_id']);

$query = "SELECT * FROM purchases_returns WHERE tenant_id = '$tenant_id' ORDER BY return_date DESC";
$result = mysqli_query($conn, $query);

$returns = [];
while ($row = mysqli_fetch_assoc($result)) {
    $returns[] = $row;
}

echo json_encode(["status" => "success", "data" => $returns]);
mysqli_close($conn);
?>
```

### 3. `delete_return.php`
```php
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

include 'db_config.php';

$data = json_decode(file_get_contents("php://input"), true);
$tenant_id = mysqli_real_escape_string($conn, $data['tenant_id']);
$return_id = mysqli_real_escape_string($conn, $data['return_id']);

$query = "DELETE FROM purchases_returns WHERE id = '$return_id' AND tenant_id = '$tenant_id'";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Return deleted"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}

mysqli_close($conn);
?>
```
