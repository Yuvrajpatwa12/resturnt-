<?php
require_once 'db_config.php';

try {
    // 1. Marketing Offers (Banners/Deals)
    $conn->exec("CREATE TABLE IF NOT EXISTS marketing_offers (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(50) NOT NULL,
        title VARCHAR(100) NOT NULL,
        subtitle VARCHAR(255),
        discount_tag VARCHAR(50), -- e.g. '50% OFF'
        image_url VARCHAR(255),
        is_active TINYINT(1) DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");

    echo "<h1>✅ Offers Table Initialized!</h1>";
} catch (PDOException $e) {
    die("❌ Setup Failed: " . $e->getMessage());
}
?>
