# Supplier Management Backend Scripts

Upload these files to your Hostinger server at `/public_html/saas_api/`.

### 1. `get_suppliers.php`
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

$query = "SELECT * FROM suppliers WHERE tenant_id = '$tenant_id' ORDER BY name ASC";
$result = mysqli_query($conn, $query);

$suppliers = [];
while ($row = mysqli_fetch_assoc($result)) {
    $suppliers[] = $row;
}

echo json_encode(["status" => "success", "data" => $suppliers]);
mysqli_close($conn);
?>
```

### 2. `add_supplier.php`
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

$tenant_id = mysqli_real_escape_string($conn, $data['tenant_id']);
$name = mysqli_real_escape_string($conn, $data['name']);
$contact_person = mysqli_real_escape_string($conn, $data['contact_person']);
$phone = mysqli_real_escape_string($conn, $data['phone']);
$email = mysqli_real_escape_string($conn, $data['email']);
$category = mysqli_real_escape_string($conn, $data['category']);
$budget_limit = mysqli_real_escape_string($conn, $data['budget_limit']);

$query = "INSERT INTO suppliers (tenant_id, name, contact_person, phone, email, category, budget_limit)
          VALUES ('$tenant_id', '$name', '$contact_person', '$phone', '$email', '$category', '$budget_limit')";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Supplier added"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}

mysqli_close($conn);
?>
```

### 3. `update_supplier.php`
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

$id = mysqli_real_escape_string($conn, $data['id']);
$tenant_id = mysqli_real_escape_string($conn, $data['tenant_id']);
$name = mysqli_real_escape_string($conn, $data['name']);
$phone = mysqli_real_escape_string($conn, $data['phone']);
$email = mysqli_real_escape_string($conn, $data['email']);
$category = mysqli_real_escape_string($conn, $data['category']);
$budget_limit = mysqli_real_escape_string($conn, $data['budget_limit']);

$query = "UPDATE suppliers SET name='$name', phone='$phone', email='$email', category='$category', budget_limit='$budget_limit'
          WHERE id='$id' AND tenant_id='$tenant_id'";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Supplier updated"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}

mysqli_close($conn);
?>
```

### 4. `delete_supplier.php`
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
$id = mysqli_real_escape_string($conn, $data['id']);
$tenant_id = mysqli_real_escape_string($conn, $data['tenant_id']);

$query = "DELETE FROM suppliers WHERE id='$id' AND tenant_id='$tenant_id'";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Supplier deleted"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}

mysqli_close($conn);
?>
```
