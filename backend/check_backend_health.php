<?php
/**
 * check_backend_health.php - Full System Diagnostic & Health Check Script for saas_api
 * Upload to saas_api and open in browser to verify files, database tables, and email setup.
 */

header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

function h($val) {
    return htmlspecialchars((string)$val, ENT_QUOTES, 'UTF-8');
}

$results = [];

function checkReport(&$results, $category, $name, $status, $message, $details = '') {
    $results[] = [
        'category' => $category,
        'name' => $name,
        'status' => $status,
        'message' => $message,
        'details' => $details
    ];
}

// 1. Check PHP Version & Extensions
$phpVersion = PHP_VERSION;
$hasMysqli = extension_loaded('mysqli');
$hasCurl = extension_loaded('curl');
$hasJson = extension_loaded('json');

checkReport($results, 'PHP Environment', 'PHP Version', true, "Running PHP $phpVersion");
checkReport($results, 'PHP Environment', 'MySQLi Extension', $hasMysqli, $hasMysqli ? 'MySQLi extension installed' : 'MySQLi extension missing');
checkReport($results, 'PHP Environment', 'cURL Extension (For Resend Email API)', $hasCurl, $hasCurl ? 'cURL extension installed' : 'cURL extension missing');
checkReport($results, 'PHP Environment', 'JSON Extension', $hasJson, $hasJson ? 'JSON extension installed' : 'JSON extension missing');

// 2. Check Database Connection
$dbConfigPath = __DIR__ . '/db_config.php';
$conn = null;

if (file_exists($dbConfigPath)) {
    checkReport($results, 'Database', 'db_config.php', true, 'File found beside script');
    try {
        require_once $dbConfigPath;
        if (isset($conn) && $conn instanceof mysqli && !$conn->connect_error) {
            checkReport($results, 'Database', 'MySQL Connection', true, 'Successfully connected to MySQL database');
        } else {
            $err = isset($conn->connect_error) ? $conn->connect_error : 'Unknown DB connection error';
            checkReport($results, 'Database', 'MySQL Connection', false, "Connection failed: $err");
        }
    } catch (Throwable $e) {
        checkReport($results, 'Database', 'MySQL Connection', false, "Exception: " . $e->getMessage());
    }
} else {
    checkReport($results, 'Database', 'db_config.php', false, 'Missing db_config.php in saas_api directory');
}

// 3. Check Required API Endpoint Files
$requiredFiles = [
    'init_tenant.php' => 'Multi-Tenant & Admin Profile Persistence API',
    'support_tickets_api.php' => 'Support Ticket & Reply Engine',
    'send_ticket_reply.php' => 'Support Ticket Reply Endpoint Alias',
    'get_ticket_history.php' => 'Support Ticket History Endpoint Alias',
    'email_notification_common.php' => 'Resend Email Queueing & Immediate Dispatch Helper',
    'place_order.php' => 'Customer Order Placement API',
    'get_all_orders.php' => 'POS & KDS Orders API',
    'subscription_api.php' => 'SaaS Subscription Lifecycle API',
    'payment_methods_api.php' => 'Merchant Payment Gateways API',
    'ingredients_api.php' => 'Raw Ingredient Inventory API',
    'units_api.php' => 'Measurement Units API',
    'loyalty_api.php' => 'Loyalty Rewards & Mystery Box API',
    'nearby_api.php' => 'Diner Presence & Social Wave API',
    'chat_api.php' => 'Live 1-on-1 Chat API',
    'music_api.php' => 'Jukebox & Music Poll API',
    'theme_api.php' => 'Dynamic Brand Theme API'
];

foreach ($requiredFiles as $file => $label) {
    $exists = file_exists(__DIR__ . '/' . $file);
    checkReport($results, 'API Endpoints', "$file ($label)", $exists, $exists ? 'File present on server' : 'MISSING file on server');
}

// 4. Check & Auto-Create Required MySQL Database Tables (If DB Connected)
if (isset($conn) && $conn instanceof mysqli && !$conn->connect_error) {
    @$conn->query("CREATE TABLE IF NOT EXISTS support_tickets (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(100) NOT NULL,
        subject VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        status VARCHAR(50) DEFAULT 'Open',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    @$conn->query("CREATE TABLE IF NOT EXISTS support_ticket_replies (
        id INT AUTO_INCREMENT PRIMARY KEY,
        ticket_id INT NOT NULL,
        sender VARCHAR(100) DEFAULT 'Tenant',
        sender_type VARCHAR(50) DEFAULT 'Tenant',
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    @$conn->query("CREATE TABLE IF NOT EXISTS notifications (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(100) NOT NULL,
        user_id VARCHAR(100) NOT NULL,
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        type VARCHAR(50) DEFAULT 'general',
        is_read TINYINT(1) DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    @$conn->query("CREATE TABLE IF NOT EXISTS notification_email_queue (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(100) NOT NULL,
        user_id VARCHAR(255) NOT NULL,
        notification_id INT NOT NULL,
        event_type VARCHAR(50) NOT NULL,
        status VARCHAR(20) DEFAULT 'pending',
        attempts INT DEFAULT 0,
        last_error TEXT DEFAULT NULL,
        available_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        sent_at TIMESTAMP NULL DEFAULT NULL,
        processing_started_at TIMESTAMP NULL DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $requiredTables = [
        'tenants' => 'Stores Restaurant Profiles, Domain, Theme, Contact Email & Phone',
        'orders' => 'Customer & POS Orders Table',
        'products' => 'Food Menu Catalog Table',
        'categories' => 'Menu Categories Table',
        'staff' => 'Restaurant Staff & Waiter Accounts Table',
        'support_tickets' => 'Customer & Restaurant Admin Support Tickets',
        'support_ticket_replies' => 'Support Ticket Chat Messages',
        'notifications' => 'System Notifications Table',
        'notification_email_queue' => 'Resend Email Dispatch Queue',
        'subscription_packages' => 'SaaS Subscription Packages Table',
        'subscription_requests' => 'Tenant Upgrade Requests Table',
        'ingredients' => 'Raw Ingredients Inventory Table',
        'units' => 'Measurement Units Table'
    ];

    foreach ($requiredTables as $table => $desc) {
        $res = $conn->query("SHOW TABLES LIKE '$table'");
        $tableExists = ($res && $res->num_rows > 0);
        checkReport($results, 'Database Tables', "`$table` ($desc)", $tableExists, $tableExists ? 'Table exists in database' : 'MISSING database table');
    }

    $tenantRes = $conn->query("SELECT tenant_id, restaurant_name, contact_email, contact_phone, location FROM tenants LIMIT 5");
    if ($tenantRes && $tenantRes->num_rows > 0) {
        $tenantCount = $tenantRes->num_rows;
        $detailsArr = [];
        while ($row = $tenantRes->fetch_assoc()) {
            $email = !empty($row['contact_email']) ? $row['contact_email'] : 'NOT SET';
            $detailsArr[] = "Tenant: {$row['tenant_id']} | Name: {$row['restaurant_name']} | Email: $email";
        }
        checkReport($results, 'Tenant Profiles', 'Tenants Table Data', true, "Found $tenantCount tenant profile(s)", implode('<br>', $detailsArr));
    } else {
        checkReport($results, 'Tenant Profiles', 'Tenants Table Data', false, 'No tenant rows found in tenants table');
    }
}

// 5. Check Resend Email API Key Configuration
if (file_exists(__DIR__ . '/email_notification_common.php')) {
    require_once __DIR__ . '/email_notification_common.php';
    if (function_exists('resendEmailConfig')) {
        $config = resendEmailConfig();
        $keyStatus = !empty($config['api_key']);
        $fromEmail = !empty($config['from']) ? $config['from'] : 'noreply@startupsgo.tech';
        checkReport($results, 'Email System', 'Resend API Key Config', $keyStatus, $keyStatus ? "API Key configured. Sender: $fromEmail" : 'API Key missing in resend_config.php or environment');
    }
}

$passCount = 0;
$failCount = 0;
foreach ($results as $r) {
    if ($r['status']) $passCount++; else $failCount++;
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>ChiyaBreak saas_api Health Diagnostic Board</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; padding: 24px; line-height: 1.5; }
        .container { max-width: 1000px; margin: 0 auto; }
        .header { background: #1e293b; padding: 24px; border-radius: 16px; border: 1px solid #334155; margin-bottom: 24px; display: flex; justify-content: space-between; align-items: center; }
        h1 { margin: 0; font-size: 22px; color: #38bdf8; }
        .badge { padding: 6px 14px; border-radius: 20px; font-weight: bold; font-size: 13px; }
        .badge-pass { background: rgba(34,197,94,0.2); color: #4ade80; border: 1px solid #22c55e; }
        .badge-fail { background: rgba(239,68,68,0.2); color: #f87171; border: 1px solid #ef4444; }
        .card { background: #1e293b; padding: 20px; border-radius: 16px; border: 1px solid #334155; margin-bottom: 20px; }
        h2 { font-size: 16px; margin-top: 0; margin-bottom: 12px; color: #94a3b8; border-bottom: 1px solid #334155; padding-bottom: 8px; }
        table { width: 100%; border-collapse: collapse; }
        td, th { padding: 10px 12px; text-align: left; font-size: 13px; border-bottom: 1px solid #334155; }
        th { color: #94a3b8; font-weight: 600; }
        .status-pass { color: #4ade80; font-weight: bold; }
        .status-fail { color: #f87171; font-weight: bold; }
        .details { font-size: 11px; color: #94a3b8; font-family: monospace; }
        .btn { background: #0284c7; color: white; border: none; padding: 10px 20px; border-radius: 8px; font-weight: bold; cursor: pointer; text-decoration: none; display: inline-block; }
        .btn:hover { background: #0369a1; }
    </style>
</head>
<body>

<div class="container">
    <div class="header">
        <div>
            <h1>🛠️ ChiyaBreak saas_api Health Diagnostic Board</h1>
            <p style="margin: 4px 0 0 0; color: #94a3b8; font-size: 13px;">Full System & Database Diagnostic Tool</p>
        </div>
        <div>
            <span class="badge badge-pass"><?= $passCount ?> PASSED</span>
            <?php if ($failCount > 0): ?>
                <span class="badge badge-fail"><?= $failCount ?> FAILED</span>
            <?php endif; ?>
        </div>
    </div>

    <?php
    $grouped = [];
    foreach ($results as $r) {
        $grouped[$r['category']][] = $r;
    }
    foreach ($grouped as $cat => $items):
    ?>
        <div class="card">
            <h2><?= h($cat) ?></h2>
            <table>
                <thead>
                    <tr>
                        <th style="width: 35%;">Component / File</th>
                        <th style="width: 15%;">Status</th>
                        <th style="width: 50%;">Diagnostic Message</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($items as $item): ?>
                        <tr>
                            <td><strong><?= h($item['name']) ?></strong></td>
                            <td class="<?= $item['status'] ? 'status-pass' : 'status-fail' ?>">
                                <?= $item['status'] ? '✓ PASS' : '✗ FAIL' ?>
                            </td>
                            <td>
                                <?= h($item['message']) ?>
                                <?php if (!empty($item['details'])): ?>
                                    <br><span class="details"><?= h($item['details']) ?></span>
                                <?php endif; ?>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endforeach; ?>

    <div style="text-align: center; margin-top: 30px;">
        <a href="check_backend_health.php" class="btn">🔄 Re-Run Full Diagnostic Check</a>
    </div>
</div>

</body>
</html>
