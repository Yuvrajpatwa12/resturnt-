<?php
/**
 * wipe_test_data.php
 * Run this ONCE in your browser to clear all old test orders.
 * Example: your-domain.com/saas_api/wipe_test_data.php
 */
require_once 'db_config.php';

$queries = [
    "DELETE FROM order_items",
    "DELETE FROM orders",
    "DELETE FROM restaurant_presence",
    "UPDATE restaurant_tables SET status = 'Available'"
];

echo "<h2>Cleaning Up Database...</h2>";

foreach ($queries as $q) {
    if ($conn->query($q) === TRUE) {
        echo "✅ Query executed: $q <br>";
    } else {
        echo "❌ Error: " . $conn->error . "<br>";
    }
}

echo "<h3>✅ Cleanup Complete! You can now place fresh orders.</h3>";
$conn->close();
?>
