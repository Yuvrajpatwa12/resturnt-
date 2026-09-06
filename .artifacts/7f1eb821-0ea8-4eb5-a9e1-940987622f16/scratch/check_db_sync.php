<?php
/**
 * check_db_sync.php
 * Run this in your browser to verify if your database has the new columns.
 */
require_once 'db_config.php';

echo "<h2>Verifying Database Schema...</h2>";

$columns_to_check = [
    'customers' => ['gender', 'is_anonymous'],
    'orders' => ['user_id', 'customer_email']
];

foreach ($columns_to_check as $table => $cols) {
    echo "<h3>Table: $table</h3>";
    foreach ($cols as $col) {
        $res = $conn->query("SHOW COLUMNS FROM `$table` LIKE '$col'");
        if ($res->num_rows > 0) {
            echo "✅ Column '$col' exists.<br>";
        } else {
            echo "❌ Column '$col' is MISSING! Please run the SQL setup again.<br>";
        }
    }
}

echo "<h3>✅ Verification Finished.</h3>";
$conn->close();
?>
