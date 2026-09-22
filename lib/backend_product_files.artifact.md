# Backend Requirements for Product Menu

To ensure products and images appear correctly in your app, you must have these specific files in your Hostinger `/saas_api/` folder.

## 1. `db_config.php`
*Connects your PHP code to the MySQL database.*

```php
<?php
$host = "localhost";
$db_name = "u642040880_admin_user";
$username = "u642040880_unhr_db";
$password = "Yuraj&11";

$conn = mysqli_connect($host, $username, $password, $db_name);
if (!$conn) {
    die(json_encode(["status" => "error", "message" => "DB Connection Failed"]));
}
mysqli_set_charset($conn, "utf8");
date_default_timezone_set('Asia/Kathmandu');
?>
```

## 2. `get_menu.php`
*Fetches categories and products to display in the app.*

```php
<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
require_once 'db_config.php';

$tenant_id = $_GET['tenant_id'] ?? '';

if (empty($tenant_id)) {
    echo json_encode(["status" => "error", "message" => "Missing Tenant ID"]);
    exit;
}

// 1. Fetch Categories
$cat_res = $conn->query("SELECT id, title, icon, rank FROM categories WHERE tenant_id = '$tenant_id' ORDER BY rank ASC");
$categories = $cat_res->fetch_all(MYSQLI_ASSOC);

// 2. Fetch Products
$prod_res = $conn->query("SELECT p.*, c.title as tag FROM products p
                          LEFT JOIN categories c ON p.category_id = c.id
                          WHERE p.tenant_id = '$tenant_id'");
$products = $prod_res->fetch_all(MYSQLI_ASSOC);

echo json_encode([
    "status" => "success",
    "categories" => $categories,
    "products" => $products
]);
?>
```

## 3. `uploads/` Folder
*Stores your food photos.*

> [!IMPORTANT]
> - Ensure there is a folder named `uploads` inside your `saas_api` directory.
> - **Permissions**: Set the folder permissions to **755** or **777** so the server can save and read images.
> - **Sub-folders**: The app expects these folders inside `uploads/`:
>   - `uploads/groups/`
>   - `uploads/payments/`

## 4. `.htaccess`
*Bypasses CORS blocks and enables clean routing.*

```apache
<IfModule mod_headers.c>
    Header set Access-Control-Allow-Origin "*"
</IfModule>

<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule . index.html [L]
</IfModule>
```
