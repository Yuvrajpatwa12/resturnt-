# Backend PHP Scripts for Hostinger

Upload these files to your Hostinger server at `/public_html/saas_api/`.

### 1. `add_category.php`
```php
<?php
header("Content-Type: application/json");
include 'db_config.php'; // Ensure this file exists with your DB credentials

$data = json_decode(file_get_contents("php://input"), true);
$tenant_id = $data['tenant_id'];
$title = $data['title'];
$rank = $data['rank'];

$query = "INSERT INTO categories (tenant_id, title, rank) VALUES ('$tenant_id', '$title', '$rank')";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Category added"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}
?>
```

### 2. `delete_category.php`
```php
<?php
header("Content-Type: application/json");
include 'db_config.php';

$data = json_decode(file_get_contents("php://input"), true);
$tenant_id = $data['tenant_id'];
$category_id = $data['category_id'];

$query = "DELETE FROM categories WHERE id = '$category_id' AND tenant_id = '$tenant_id'";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Category deleted"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}
?>
```

### 3. `add_purchase.php`
```php
<?php
header("Content-Type: application/json");
include 'db_config.php';

$data = json_decode(file_get_contents("php://input"), true);
$tenant_id = $data['tenant_id'];
$ingredient_name = $data['ingredient_name'];
$supplier_name = $data['supplier_name'];
$quantity = $data['quantity'];
$unit = $data['unit'];
$total_price = $data['total_price'];
$purchase_date = date("Y-m-d H:i:s");

$query = "INSERT INTO purchases (tenant_id, ingredient_name, supplier_name, quantity, unit, total_price, purchase_date)
          VALUES ('$tenant_id', '$ingredient_name', '$supplier_name', '$quantity', '$unit', '$total_price', '$purchase_date')";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Purchase added"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}
?>
```

### 4. `get_purchases.php`
```php
<?php
header("Content-Type: application/json");
include 'db_config.php';

$tenant_id = $_GET['tenant_id'];

$query = "SELECT * FROM purchases WHERE tenant_id = '$tenant_id' ORDER BY purchase_date DESC";
$result = mysqli_query($conn, $query);

$purchases = [];
while ($row = mysqli_fetch_assoc($result)) {
    $purchases[] = $row;
}

echo json_encode(["status" => "success", "data" => $purchases]);
?>
```

### 5. `delete_purchase.php`
```php
<?php
header("Content-Type: application/json");
include 'db_config.php';

$data = json_decode(file_get_contents("php://input"), true);
$tenant_id = $data['tenant_id'];
$purchase_id = $data['purchase_id'];

$query = "DELETE FROM purchases WHERE id = '$purchase_id' AND tenant_id = '$tenant_id'";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Purchase deleted"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}
?>
```

### 6. `get_all_orders.php`
```php
<?php
header("Content-Type: application/json");
include 'db_config.php';

$tenant_id = $_GET['tenant_id'];

$query = "SELECT * FROM orders WHERE tenant_id = '$tenant_id' ORDER BY created_at DESC";
$result = mysqli_query($conn, $query);

$orders = [];
while ($row = mysqli_fetch_assoc($result)) {
    $order_id = $row['id'];
    // Fetch items for each order
    $item_query = "SELECT * FROM order_items WHERE order_id = '$order_id'";
    $item_result = mysqli_query($conn, $item_query);
    $items = [];
    while ($item_row = mysqli_fetch_assoc($item_result)) {
        $items[] = $item_row;
    }
    $row['items'] = $items;
    $orders[] = $row;
}

echo json_encode(["status" => "success", "data" => $orders]);
?>
```

### 7. `delete_order.php`
```php
<?php
header("Content-Type: application/json");
include 'db_config.php';

$data = json_decode(file_get_contents("php://input"), true);
$tenant_id = $data['tenant_id'];
$order_id = $data['order_id'];

// First delete items
mysqli_query($conn, "DELETE FROM order_items WHERE order_id = '$order_id'");

// Then delete order
$query = "DELETE FROM orders WHERE id = '$order_id' AND tenant_id = '$tenant_id'";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Order deleted"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}
?>
```

### 8. `delete_product.php`
```php
<?php
header("Content-Type: application/json");
include 'db_config.php';

$data = json_decode(file_get_contents("php://input"), true);
$tenant_id = $data['tenant_id'];
$product_id = $data['product_id'];

$query = "DELETE FROM products WHERE id = '$product_id' AND tenant_id = '$tenant_id'";

if (mysqli_query($conn, $query)) {
    echo json_encode(["status" => "success", "message" => "Product deleted"]);
} else {
    echo json_encode(["status" => "error", "message" => mysqli_error($conn)]);
}
?>
```

> [!NOTE]
> Make sure your database tables (`categories`, `purchases`, `products`, `orders`, `order_items`) have the `tenant_id` column to enable isolation.
