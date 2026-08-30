# Advanced HRM Backend Scripts

Replace your existing staff management files in `/public_html/saas_api/` with these versions to support the new detailed employee fields.

### 1. `add_staff.php`
```php
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

include 'db_config.php';
$data = json_decode(file_get_contents("php://input"), true);

if (!$data || !isset($data['tenant_id']) || empty($data['email'])) {
    echo json_encode(["status" => "error", "message" => "Missing core data"]);
    exit;
}

$tenant_id = mysqli_real_escape_string($conn, $data['tenant_id']);
$name = mysqli_real_escape_string($conn, $data['name']);
$email = mysqli_real_escape_string($conn, $data['email']);
$role = mysqli_real_escape_string($conn, $data['role']);
$pin = mysqli_real_escape_string($conn, $data['pin']);

// New Fields
$salary = mysqli_real_escape_string($conn, $data['salary_amount'] ?? '0.00');
$cycle = mysqli_real_escape_string($conn, $data['payment_cycle_days'] ?? '30');
$phone = mysqli_real_escape_string($conn, $data['phone_number'] ?? '');
$c_addr = mysqli_real_escape_string($conn, $data['current_address'] ?? '');
$p_addr = mysqli_real_escape_string($conn, $data['permanent_address'] ?? '');
$citizen = mysqli_real_escape_string($conn, $data['citizenship_number'] ?? '');
$doc = mysqli_real_escape_string($conn, $data['document_url'] ?? '');

$query = "INSERT INTO users (tenant_id, name, email, role, login_pin, salary_amount, payment_cycle_days, phone_number, current_address, permanent_address, citizenship_number, document_url)
          VALUES ('$tenant_id', '$name', '$email', '$role', '$pin', '$salary', '$cycle', '$phone', '$c_addr', '$p_addr', '$citizen', '$doc')";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Staff registered"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}
mysqli_close($conn);
?>
```

### 2. `update_staff.php`
```php
<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json");

include 'db_config.php';
$data = json_decode(file_get_contents("php://input"), true);

$id = mysqli_real_escape_string($conn, $data['user_id']);
$name = mysqli_real_escape_string($conn, $data['name']);
$role = mysqli_real_escape_string($conn, $data['role']);
$pin = mysqli_real_escape_string($conn, $data['pin']);

// New Fields
$salary = mysqli_real_escape_string($conn, $data['salary_amount'] ?? '0.00');
$cycle = mysqli_real_escape_string($conn, $data['payment_cycle_days'] ?? '30');
$phone = mysqli_real_escape_string($conn, $data['phone_number'] ?? '');
$c_addr = mysqli_real_escape_string($conn, $data['current_address'] ?? '');
$p_addr = mysqli_real_escape_string($conn, $data['permanent_address'] ?? '');
$citizen = mysqli_real_escape_string($conn, $data['citizenship_number'] ?? '');
$doc = mysqli_real_escape_string($conn, $data['document_url'] ?? '');

$query = "UPDATE users SET
          name='$name',
          role='$role',
          login_pin='$pin',
          salary_amount='$salary',
          payment_cycle_days='$cycle',
          phone_number='$phone',
          current_address='$c_addr',
          permanent_address='$p_addr',
          citizenship_number='$citizen',
          document_url='$doc'
          WHERE id='$id'";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Staff updated"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}
mysqli_close($conn);
?>
```
