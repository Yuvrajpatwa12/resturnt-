<?php
/**
 * debug_tenant_profile.php - Live Database Row Inspector for Restaurant Tenant Profiles
 * Allows inspecting the exact row saved in the MySQL 'tenants' table.
 */
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

function h($value) {
    return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
}

$tenantId = $_GET['tenant_id'] ?? 'startups_main';
$dbConfig = __DIR__ . '/db_config.php';

if (!is_file($dbConfig)) {
    die("Error: db_config.php not found.");
}
require_once $dbConfig;

$message = '';

// Handle Test Save Action
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $r_name = trim($_POST['restaurant_name'] ?? '');
    $c_email = trim($_POST['contact_email'] ?? '');
    $c_phone = trim($_POST['contact_phone'] ?? '');
    $loc = trim($_POST['location'] ?? '');
    $t_id = trim($_POST['tenant_id'] ?? $tenantId);

    if (!empty($t_id)) {
        @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS contact_email VARCHAR(255) DEFAULT ''");
        @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(50) DEFAULT ''");
        @$conn->query("ALTER TABLE tenants ADD COLUMN IF NOT EXISTS location VARCHAR(255) DEFAULT ''");

        $stmt = $conn->prepare("UPDATE tenants SET restaurant_name = ?, contact_email = ?, contact_phone = ?, location = ? WHERE tenant_id = ? OR custom_domain = ?");
        $stmt->bind_param("ssssss", $r_name, $c_email, $c_phone, $loc, $t_id, $t_id);
        if ($stmt->execute()) {
            $message = "SUCCESS: Profile updated in MySQL table 'tenants' for tenant_id [$t_id]!";
        } else {
            $message = "ERROR: " . $conn->error;
        }
    }
}

// Fetch Current Row from MySQL
$stmt = $conn->prepare("SELECT * FROM tenants WHERE tenant_id = ? OR custom_domain = ? LIMIT 1");
$stmt->bind_param("ss", $tenantId, $tenantId);
$stmt->execute();
$res = $stmt->get_result();
$row = $res->fetch_assoc();

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Tenant Profile Database Row Inspector</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f8fafc; color: #0f172a; padding: 24px; line-height: 1.5; }
        .card { background: white; padding: 24px; border-radius: 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); margin-bottom: 24px; max-width: 900px; }
        h1 { font-size: 20px; font-weight: 800; margin-top: 0; color: #1e3a8a; }
        h2 { font-size: 16px; font-weight: 700; margin-top: 0; color: #334155; }
        table { width: 100%; border-collapse: collapse; margin-top: 12px; }
        th, td { border: 1px solid #e2e8f0; padding: 12px; font-size: 13px; text-align: left; }
        th { background: #f1f5f9; font-weight: 700; color: #475569; }
        .highlight { background: #e0f2fe; font-weight: bold; color: #0369a1; }
        .msg { padding: 12px 16px; border-radius: 8px; font-weight: bold; margin-bottom: 16px; background: #dcfce7; color: #15803d; }
        input[type=text], input[type=email] { width: 100%; padding: 10px; border: 1px solid #cbd5e1; border-radius: 8px; box-sizing: border-box; font-size: 13px; }
        button { background: #2563eb; color: white; border: none; padding: 12px 20px; border-radius: 8px; font-weight: bold; cursor: pointer; font-size: 13px; margin-top: 12px; }
        button:hover { background: #1d4ed8; }
    </style>
</head>
<body>

<div class="card">
    <h1>📊 MySQL Database Row Inspector (`tenants` Table)</h1>
    <p>Inspecting row for <strong>Tenant ID / Domain:</strong> <code><?= h($tenantId) ?></code></p>

    <?php if ($message): ?>
        <div class="msg"><?= h($message) ?></div>
    <?php endif; ?>

    <?php if ($row): ?>
        <h2>Saved Row Data in MySQL Database:</h2>
        <table>
            <tr><th>Column Name</th><th>Saved Value in Database</th><th>Status</th></tr>
            <tr class="highlight"><td><code>id</code></td><td><?= h($row['id'] ?? 'N/A') ?></td><td>Primary Key</td></tr>
            <tr class="highlight"><td><code>tenant_id</code></td><td><?= h($row['tenant_id'] ?? 'N/A') ?></td><td>Tenant Identifier</td></tr>
            <tr class="highlight"><td><code>restaurant_name</code></td><td><strong><?= h($row['restaurant_name'] ?? 'N/A') ?></strong></td><td>Saved Name</td></tr>
            <tr class="highlight"><td><code>contact_email</code></td><td><strong><?= h($row['contact_email'] ?? 'N/A') ?></strong></td><td>Saved Notification Email</td></tr>
            <tr class="highlight"><td><code>contact_phone</code></td><td><strong><?= h($row['contact_phone'] ?? 'N/A') ?></strong></td><td>Saved Phone</td></tr>
            <tr class="highlight"><td><code>location</code></td><td><strong><?= h($row['location'] ?? 'N/A') ?></strong></td><td>Saved Address</td></tr>
            <tr><td><code>custom_domain</code></td><td><?= h($row['custom_domain'] ?? 'N/A') ?></td><td>Domain</td></tr>
            <tr><td><code>plan</code></td><td><?= h($row['plan'] ?? 'N/A') ?></td><td>SaaS Plan</td></tr>
            <tr><td><code>subscription_status</code></td><td><?= h($row['subscription_status'] ?? 'N/A') ?></td><td>Status</td></tr>
        </table>
    <?php else: ?>
        <p style="color: red; font-weight: bold;">No row found in 'tenants' table for tenant_id: <?= h($tenantId) ?></p>
    <?php endif; ?>
</div>

<div class="card">
    <h2>🧪 Test Live Profile Update Directly on Database Row</h2>
    <form method="POST">
        <input type="hidden" name="tenant_id" value="<?= h($tenantId) ?>">
        <p><label>Restaurant Name:</label><br><input type="text" name="restaurant_name" value="<?= h($row['restaurant_name'] ?? 'ChiyaBreak Restaurant') ?>"></p>
        <p><label>Contact Email (Notification Target):</label><br><input type="email" name="contact_email" value="<?= h($row['contact_email'] ?? 'admin@chiyabreak.com') ?>"></p>
        <p><label>Contact Phone:</label><br><input type="text" name="contact_phone" value="<?= h($row['contact_phone'] ?? '+977-9800000000') ?>"></p>
        <p><label>Location Address:</label><br><input type="text" name="location" value="<?= h($row['location'] ?? 'Main Road, Butwal, Nepal') ?>"></p>
        <button type="submit">UPDATE MYSQL ROW NOW</button>
    </form>
</div>

</body>
</html>
