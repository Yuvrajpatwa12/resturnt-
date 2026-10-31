<?php
/**
 * test_theme_api.php - Theme API Testing Tool
 * Use this file to test if theme_api.php is working correctly
 * 
 * Usage: Open in browser: https://startupsgo.tech/saas_api/test_theme_api.php
 */

header("Access-Control-Allow-Origin: *");
header("Content-Type: text/html; charset=UTF-8");

$baseUrl = "https://startupsgo.tech/saas_api";
$testTenantId = "startups_main";

?>
<!DOCTYPE html>
<html>
<head>
    <title>Theme API Test</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 20px; max-width: 800px; margin: 0 auto; }
        .test-section { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 8px; }
        .success { background: #d4edda; border-color: #c3e6cb; }
        .error { background: #f8d7da; border-color: #f5c6cb; }
        .info { background: #d1ecf1; border-color: #bee5eb; }
        pre { background: #f8f9fa; padding: 10px; border-radius: 4px; overflow-x: auto; }
        h2 { margin-top: 0; }
        .status { font-weight: bold; }
    </style>
</head>
<body>
    <h1>🎨 Theme API Test Tool</h1>
    <p>Testing theme API endpoints for tenant: <strong><?php echo $testTenantId; ?></strong></p>
    
    <?php
    function testEndpoint($url, $name) {
        echo "<div class='test-section'>";
        echo "<h3>$name</h3>";
        echo "<p><strong>URL:</strong> <code>$url</code></p>";
        
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);
        
        if ($error) {
            echo "<div class='error'><span class='status'>❌ ERROR:</span> $error</div>";
        } else {
            echo "<p><strong>HTTP Status:</strong> $httpCode</p>";
            
            $json = json_decode($response, true);
            if ($json === null) {
                echo "<div class='error'><span class='status'>❌ Invalid JSON Response:</span></div>";
                echo "<pre>" . htmlspecialchars($response) . "</pre>";
            } else {
                if ($json['status'] == 'success') {
                    echo "<div class='success'><span class='status'>✅ SUCCESS</span></div>";
                } else {
                    echo "<div class='error'><span class='status'>❌ API Error:</span> " . ($json['message'] ?? 'Unknown error') . "</div>";
                }
                echo "<pre>" . json_encode($json, JSON_PRETTY_PRINT) . "</pre>";
            }
        }
        echo "</div>";
    }
    
    // Test 1: Check if theme_api.php exists
    echo "<div class='test-section info'>";
    echo "<h3>📋 File Existence Check</h3>";
    $apiFile = $baseUrl . "/theme_api.php";
    echo "<p>Checking: <code>$apiFile</code></p>";
    $ch = curl_init($apiFile);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode == 200) {
        echo "<div class='success'><span class='status'>✅ File exists and is accessible</span></div>";
    } else {
        echo "<div class='error'><span class='status'>❌ File not found or not accessible (HTTP $httpCode)</span></div>";
        echo "<p><strong>Action Required:</strong> Upload theme_api.php to saas_api folder</p>";
    }
    echo "</div>";
    
    // Test 2: Get Theme
    testEndpoint($baseUrl . "/theme_api.php?action=get_theme&tenant_id=" . $testTenantId, "🔍 Test 1: Fetch Theme");
    
    // Test 3: List All Themes
    testEndpoint($baseUrl . "/theme_api.php?action=list_themes", "📋 Test 2: List All Themes");
    
    // Test 4: Check Database Schema
    echo "<div class='test-section info'>";
    echo "<h3>🗄️ Database Schema Check</h3>";
    echo "<p>Checking if theme columns exist in tenants table...</p>";
    echo "<p><strong>Required columns:</strong></p>";
    echo "<ul>";
    echo "<li>theme_name</li>";
    echo "<li>secondary_color</li>";
    echo "<li>background_color</li>";
    echo "<li>font_family</li>";
    echo "<li>border_radius</li>";
    echo "<li>dark_mode_enabled</li>";
    echo "<li>theme_updated_at</li>";
    echo "</ul>";
    echo "<p><strong>Action Required:</strong> Run theme_settings_setup.sql on your database</p>";
    echo "</div>";
    
    // Test 5: Check init_tenant.php
    echo "<div class='test-section info'>";
    echo "<h3>🔧 init_tenant.php Check</h3>";
    $initFile = $baseUrl . "/init_tenant.php?domain=startups_main";
    echo "<p>Checking: <code>$initFile</code></p>";
    $ch = curl_init($initFile);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    $json = json_decode($response, true);
    if ($json && isset($json['status'])) {
        echo "<div class='success'><span class='status'>✅ init_tenant.php working</span></div>";
        echo "<pre>" . json_encode($json, JSON_PRETTY_PRINT) . "</pre>";
        
        // Check if theme columns are in response
        if (isset($json['data']['theme_name'])) {
            echo "<div class='success'><span class='status'>✅ Theme columns present in tenant data</span></div>";
        } else {
            echo "<div class='error'><span class='status'>❌ Theme columns NOT in tenant data</span></div>";
            echo "<p><strong>Action Required:</strong> Run theme_settings_setup.sql on database</p>";
        }
    } else {
        echo "<div class='error'><span class='status'>❌ init_tenant.php not working</span></div>";
    }
    echo "</div>";
    ?>
    
    <div class="test-section info">
        <h3>📝 Quick Actions</h3>
        <ol>
            <li>Upload <code>theme_api.php</code> to <code>saas_api/</code> folder</li>
            <li>Upload updated <code>init_tenant.php</code> to <code>saas_api/</code> folder</li>
            <li>Run <code>theme_settings_setup.sql</code> on your database</li>
            <li>Refresh this page to re-test</li>
            <li>Restart Flutter app to see changes</li>
        </ol>
    </div>
    
    <div class="test-section info">
        <h3>🔗 Direct API Links</h3>
        <ul>
            <li><a href="<?php echo $baseUrl; ?>/theme_api.php?action=get_theme&tenant_id=<?php echo $testTenantId; ?>" target="_blank">Fetch Theme API</a></li>
            <li><a href="<?php echo $baseUrl; ?>/theme_api.php?action=list_themes" target="_blank">List All Themes API</a></li>
            <li><a href="<?php echo $baseUrl; ?>/init_tenant.php?domain=startups_main" target="_blank">Init Tenant API</a></li>
        </ul>
    </div>
</body>
</html>
