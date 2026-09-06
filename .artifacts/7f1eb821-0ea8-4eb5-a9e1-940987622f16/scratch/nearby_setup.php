<?php
/**
 * Nearby Presence System Setup
 * Run once to initialize tracking for live dining guests.
 */
require_once 'db_config.php';

if ($conn->connect_error) {
    die("❌ Connection failed: " . $conn->connect_error);
}

echo "<h2>Initializing Nearby Presence System...</h2>";

$sql = "CREATE TABLE IF NOT EXISTS restaurant_presence (
    user_id VARCHAR(100) NOT NULL,
    tenant_id VARCHAR(50) NOT NULL,
    table_number INT NOT NULL,
    user_name VARCHAR(100) DEFAULT 'Guest',
    user_image VARCHAR(255) DEFAULT '',
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, tenant_id)
)";

if ($conn->query($sql) === TRUE) {
    echo "✅ Presence table created or already exists.<br>";
} else {
    echo "❌ Error creating table: " . $conn->error . "<br>";
}

echo "<h3>✅ Setup Complete! Real-time discovery is ready.</h3>";
$conn->close();
?>
