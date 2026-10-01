# Backend Requirements for Product Menu, Variants & Preparation Time

To support product variants (Sizes, Portions, Volumes, Custom Options) and Preparation Time, run the SQL ALTER query on your MySQL database and update the PHP files in your Hostinger `/saas_api/` folder.

---

## 1. Database SQL Update (phpMyAdmin)

Run this SQL query in your phpMyAdmin database to add variant & preparation time columns to the `products` table:

```sql
ALTER TABLE products ADD COLUMN has_variants TINYINT(1) DEFAULT 0;
ALTER TABLE products ADD COLUMN variant_type VARCHAR(50) DEFAULT 'sizes';
ALTER TABLE products ADD COLUMN variants TEXT DEFAULT NULL;
ALTER TABLE products ADD COLUMN prep_time VARCHAR(50) DEFAULT '15-20 min';
```

---

## 2. `add_product.php` (Complete Code)

```php
<?php
/**
 * Chiyala SaaS - Add New Product
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

// ERROR REPORTING ON (For Debugging)
error_reporting(E_ALL);
ini_set('display_errors', 1);

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') exit;

if (!file_exists('db_config.php')) {
    die(json_encode(["status" => "error", "message" => "ERROR: db_config.php is missing in saas_api folder!"]));
}

require_once 'db_config.php';

$json = file_get_contents('php://input');
$data = json_decode($json);

if (!$data) {
    die(json_encode(["status" => "error", "message" => "ERROR: No JSON data received or invalid format!"]));
}

// Map variables
$tid            = (string)($data->tenant_id ?? 'startups_main');
$cat_id         = intval($data->category_id ?? 0);
$title          = (string)($data->title ?? '');
$price          = (string)($data->price ?? '0');
$img_url        = (string)($data->image_url ?? '');
$desc           = (string)($data->description ?? '');
$slogan         = (string)($data->slogan ?? '');
$featured       = (string)($data->featured_section ?? 'none');
$suitable_time  = (string)($data->suitable_time ?? 'All Day');
$meal_tag       = (string)($data->meal_tag ?? $data->tag ?? 'Popular');
$tag            = $meal_tag;
$m_url          = (string)($data->model_url ?? '');
$ios_m_url      = (string)($data->ios_model_url ?? '');
$prep_time      = (string)($data->prep_time ?? '15-20 min');

// Map Sizing & Variants variables
$has_variants   = intval($data->has_variants ?? 0);
$variant_type   = (string)($data->variant_type ?? 'sizes');
$variants       = is_string($data->variants ?? null) ? $data->variants : json_encode($data->variants ?? []);

// Try Insertion
try {
    $sql = "INSERT INTO products (tenant_id, category_id, title, price, image_url, description, slogan, featured_section, suitable_time, meal_tag, tag, model_url, ios_model_url, has_variants, variant_type, variants, prep_time)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }

    $stmt->bind_param("sisssssssssssisss", $tid, $cat_id, $title, $price, $img_url, $desc, $slogan, $featured, $suitable_time, $meal_tag, $tag, $m_url, $ios_m_url, $has_variants, $variant_type, $variants, $prep_time);

    if ($stmt->execute()) {
        echo json_encode(["status" => "success", "success" => true, "message" => "Product added!"]);
    } else {
        echo json_encode(["status" => "error", "success" => false, "message" => "Execute failed: " . $stmt->error]);
    }
} catch (Exception $e) {
    echo json_encode(["status" => "error", "success" => false, "message" => "CRASH ERROR: " . $e->getMessage()]);
}
?>
```

---

## 3. `update_product.php` (Complete Code)

```php
<?php
/**
 * Chiyala SaaS - Update Product
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

error_reporting(E_ALL);
ini_set('display_errors', 1);

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') exit;

if (!file_exists('db_config.php')) {
    die(json_encode(["status" => "error", "message" => "ERROR: db_config.php is missing in saas_api folder!"]));
}

require_once 'db_config.php';

$json = file_get_contents('php://input');
$data = json_decode($json);

if (!$data || empty($data->id)) {
    die(json_encode(["status" => "error", "message" => "ERROR: Product ID is required!"]));
}

$id             = intval($data->id);
$tid            = (string)($data->tenant_id ?? 'startups_main');
$cat_id         = intval($data->category_id ?? 0);
$title          = (string)($data->title ?? '');
$price          = (string)($data->price ?? '0');
$img_url        = (string)($data->image_url ?? '');
$desc           = (string)($data->description ?? '');
$slogan         = (string)($data->slogan ?? '');
$featured       = (string)($data->featured_section ?? 'none');
$suitable_time  = (string)($data->suitable_time ?? 'All Day');
$meal_tag       = (string)($data->meal_tag ?? $data->tag ?? 'Popular');
$tag            = $meal_tag;
$m_url          = (string)($data->model_url ?? '');
$ios_m_url      = (string)($data->ios_model_url ?? '');
$prep_time      = (string)($data->prep_time ?? '15-20 min');

// Map Sizing & Variants variables
$has_variants   = intval($data->has_variants ?? 0);
$variant_type   = (string)($data->variant_type ?? 'sizes');
$variants       = is_string($data->variants ?? null) ? $data->variants : json_encode($data->variants ?? []);

try {
    $sql = "UPDATE products SET category_id = ?, title = ?, price = ?, image_url = ?, description = ?, slogan = ?, featured_section = ?, suitable_time = ?, meal_tag = ?, tag = ?, model_url = ?, ios_model_url = ?, has_variants = ?, variant_type = ?, variants = ?, prep_time = ? WHERE id = ? AND tenant_id = ?";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }

    $stmt->bind_param("isssssssssssisssis", $cat_id, $title, $price, $img_url, $desc, $slogan, $featured, $suitable_time, $meal_tag, $tag, $m_url, $ios_m_url, $has_variants, $variant_type, $variants, $prep_time, $id, $tid);

    if ($stmt->execute()) {
        echo json_encode(["status" => "success", "success" => true, "message" => "Product updated!"]);
    } else {
        echo json_encode(["status" => "error", "success" => false, "message" => "Execute failed: " . $stmt->error]);
    }
} catch (Exception $e) {
    echo json_encode(["status" => "error", "success" => false, "message" => "CRASH ERROR: " . $e->getMessage()]);
}
?>
```

---

## 4. `get_menu.php` (Complete Code)

```php
<?php
/**
 * Chiyala SaaS - Final Robust Menu Handler (Categories & Products)
 * Path: public_html/saas_api/get_menu.php
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit;
}

require_once 'db_config.php';

// 1. Get Tenant ID (Default to startups_main if empty)
$tenant_id = $_GET['tenant_id'] ?? 'startups_main';

if (empty($tenant_id)) {
    echo json_encode(["status" => "error", "message" => "Tenant ID is required"]);
    exit;
}

try {
    // 2. Fetch Categories (using Prepared Statement for safety)
    $cat_query = "SELECT id, title, icon, rank FROM categories WHERE tenant_id = ? ORDER BY rank ASC";
    $stmt1 = $conn->prepare($cat_query);
    $stmt1->bind_param("s", $tenant_id);
    $stmt1->execute();
    $cat_result = $stmt1->get_result();
    $categories = $cat_result->fetch_all(MYSQLI_ASSOC);

    // 3. Fetch Products (Including suitable_time, meal_tag, prep_time, 3D/AR columns, variants, and Category Tags)
    $prod_query = "SELECT p.*, c.title as category_name
                   FROM products p
                   LEFT JOIN categories c ON p.category_id = c.id
                   WHERE p.tenant_id = ?
                   ORDER BY p.id DESC";

    $stmt2 = $conn->prepare($prod_query);
    $stmt2->bind_param("s", $tenant_id);
    $stmt2->execute();
    $prod_result = $stmt2->get_result();
    $products = $prod_result->fetch_all(MYSQLI_ASSOC);

    // 4. Ensure default fallbacks for suitable_time, meal_tag, prep_time, and variants decoding
    foreach ($products as &$p) {
        if (empty($p['suitable_time'])) {
            $p['suitable_time'] = 'All Day';
        }
        if (empty($p['meal_tag'])) {
            $p['meal_tag'] = $p['tag'] ?? 'Popular';
        }
        if (empty($p['tag'])) {
            $p['tag'] = $p['category_name'] ?? 'Popular';
        }
        if (empty($p['prep_time'])) {
            $p['prep_time'] = '15-20 min';
        }

        $p['has_variants'] = intval($p['has_variants'] ?? 0);
        $p['variant_type'] = $p['variant_type'] ?? 'sizes';

        if (isset($p['variants']) && is_string($p['variants']) && !empty($p['variants'])) {
            $decoded = json_decode($p['variants']);
            if (json_last_error() === JSON_ERROR_NONE) {
                $p['variants'] = $decoded;
            }
        }
    }
    unset($p);

    // 5. Return Combined Data
    echo json_encode([
        "status" => "success",
        "message" => "Menu data fetched successfully",
        "tenant_id" => $tenant_id,
        "categories" => $categories,
        "products" => $products
    ]);

} catch (Exception $e) {
    echo json_encode([
        "status" => "error",
        "message" => "Database Error: " . $e->getMessage()
    ]);
} finally {
    if (isset($stmt1)) $stmt1->close();
    if (isset($stmt2)) $stmt2->close();
    $conn->close();
}
?>
```
