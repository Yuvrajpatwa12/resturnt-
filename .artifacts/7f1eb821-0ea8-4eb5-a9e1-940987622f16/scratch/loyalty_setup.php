<?php
/**
 * Loyalty System Setup Script (MySQLi Version)
 * For Localhost & Hostinger Compatibility
 */
header("Content-Type: text/html; charset=UTF-8");

// --- 1. Database Connection (Update these if db_config.php doesn't exist) ---
require_once 'db_config.php';

// If your db_config.php uses PDO, we create a new MySQLi connection here:
// $conn = mysqli_connect("localhost", "your_user", "your_pass", "your_db");

if (!$conn || $conn->connect_error) {
    die("❌ Connection failed: " . ($conn->connect_error ?? "Please check db_config.php"));
}

echo "<h2>Starting Loyalty System Setup...</h2>";

$tables = [
    "loyalty_settings" => "CREATE TABLE IF NOT EXISTS loyalty_settings (
        tenant_id VARCHAR(50) PRIMARY KEY,
        points_per_order_fixed INT DEFAULT 50,
        points_per_amount DECIMAL(10,2) DEFAULT 0.05,
        group_join_bonus INT DEFAULT 200,
        mystery_box_enabled TINYINT(1) DEFAULT 1,
        min_redeem_points INT DEFAULT 100,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )",
    "redeemable_rewards" => "CREATE TABLE IF NOT EXISTS redeemable_rewards (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(50) NOT NULL,
        title VARCHAR(100) NOT NULL,
        points_required INT NOT NULL,
        image_url VARCHAR(255),
        description TEXT,
        is_active TINYINT(1) DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )",
    "reward_claims" => "CREATE TABLE IF NOT EXISTS reward_claims (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(50) NOT NULL,
        user_id VARCHAR(100) NOT NULL,
        reward_id INT NOT NULL,
        claim_code VARCHAR(20) UNIQUE NOT NULL,
        status ENUM('Pending', 'Claimed', 'Expired') DEFAULT 'Pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        claimed_at TIMESTAMP NULL
    )",
    "mystery_box_config" => "CREATE TABLE IF NOT EXISTS mystery_box_config (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(50) NOT NULL,
        reward_name VARCHAR(100) NOT NULL,
        probability DECIMAL(5,2) DEFAULT 10.00,
        image_url VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )",
    "guest_points" => "CREATE TABLE IF NOT EXISTS guest_points (
        guest_id VARCHAR(100) PRIMARY KEY,
        tenant_id VARCHAR(50) NOT NULL,
        points INT DEFAULT 0,
        order_count INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )",
    "marketing_offers" => "CREATE TABLE IF NOT EXISTS marketing_offers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(50) NOT NULL,
        title VARCHAR(100) NOT NULL,
        subtitle VARCHAR(255),
        discount_tag VARCHAR(50),
        image_url VARCHAR(255),
        is_active TINYINT(1) DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )"
];

foreach ($tables as $name => $sql) {
    if ($conn->query($sql) === TRUE) {
        echo "✅ Table '$name' created or already exists.<br>";
    } else {
        echo "❌ Error creating '$name': " . $conn->error . "<br>";
    }
}

// 7. Update Users table for Staff Points
$conn->query("ALTER TABLE users ADD COLUMN points INT DEFAULT 0");
$conn->query("ALTER TABLE users ADD COLUMN order_count INT DEFAULT 0");

echo "<h3>✅ Setup Complete! All tables are ready.</h3>";
$conn->close();
?>
