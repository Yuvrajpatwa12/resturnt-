<?php
/**
 * check_tenants.php
 * Diagnostic tool to check registered domains in your database.
 */
require_once 'db_config.php';

echo "<h2>Registered Restaurants Diagnostic</h2>";

if ($conn->connect_error) {
    die("❌ DB Connection Failed: " . $conn->connect_error);
}

$res = $conn->query("SELECT tenant_id, restaurant_name, custom_domain, is_active FROM tenants");

if ($res && $res->num_rows > 0) {
    echo "<table border='1' cellpadding='10'>";
    echo "<tr><th>ID</th><th>Name</th><th>Domain</th><th>Status</th></tr>";
    while ($row = $res->fetch_assoc()) {
        $status = $row['is_active'] ? "✅ Active" : "❌ Suspended";
        echo "<tr>";
        echo "<td>" . $row['tenant_id'] . "</td>";
        echo "<td>" . $row['restaurant_name'] . "</td>";
        echo "<td><b>" . ($row['custom_domain'] ?: 'None') . "</b></td>";
        echo "<td>$status</td>";
        echo "</tr>";
    }
    echo "</table>";
} else {
    echo "⚠️ No restaurants found in the 'tenants' table.";
}

echo "<p><i>Note: The 'Domain' column must match exactly what you see in your browser bar (e.g., startupsgo.tech).</i></p>";
$conn->close();
?>
