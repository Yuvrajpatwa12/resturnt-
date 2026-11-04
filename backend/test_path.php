<?php
header('Content-Type: text/html; charset=UTF-8');
?>
<!DOCTYPE html>
<html>
<head>
    <title>ChiyaBreak Advanced Routing & Path Diagnostic</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f1f5f9; padding: 30px; color: #1e293b; }
        .card { background: white; padding: 30px; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.05); max-width: 800px; margin: auto; }
        h2 { color: #002d62; margin-top: 0; display: flex; align-items: center; gap: 10px; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th, td { padding: 12px 16px; border-bottom: 1px solid #e2e8f0; text-align: left; font-size: 13px; font-family: monospace; }
        th { background: #f8fafc; color: #475569; font-weight: 600; font-family: sans-serif; }
        .badge-success { background: #22c55e; color: white; padding: 4px 8px; border-radius: 6px; font-size: 11px; font-family: sans-serif; font-weight: bold; }
        .section { margin-top: 25px; padding-top: 20px; border-top: 2px dashed #e2e8f0; }
        .box { background: #f8fafc; border: 1px solid #cbd5e1; padding: 15px; border-radius: 8px; margin-top: 10px; font-size: 13px; }
    </style>
</head>
<body>
<div class="card">
    <h2>🛠️ ChiyaBreak Advanced Routing & Path Diagnostic</h2>
    <p>Server running on <strong><?php echo htmlspecialchars($_SERVER['SERVER_SOFTWARE'] ?? 'Unknown'); ?></strong> (Hostinger LiteSpeed).</p>

    <table>
        <tr>
            <th>Server Parameter</th>
            <th>Value</th>
        </tr>
        <tr>
            <td><strong>REQUEST_URI</strong></td>
            <td><code><?php echo htmlspecialchars($_SERVER['REQUEST_URI'] ?? 'N/A'); ?></code></td>
        </tr>
        <tr>
            <td><strong>SCRIPT_NAME</strong></td>
            <td><code><?php echo htmlspecialchars($_SERVER['SCRIPT_NAME'] ?? 'N/A'); ?></code></td>
        </tr>
        <tr>
            <td><strong>PHP_SELF</strong></td>
            <td><code><?php echo htmlspecialchars($_SERVER['PHP_SELF'] ?? 'N/A'); ?></code></td>
        </tr>
        <tr>
            <td><strong>PATH_INFO</strong></td>
            <td><code><?php echo htmlspecialchars($_SERVER['PATH_INFO'] ?? 'Not Set'); ?></code></td>
        </tr>
        <tr>
            <td><strong>SERVER_SOFTWARE</strong></td>
            <td><code><?php echo htmlspecialchars($_SERVER['SERVER_SOFTWARE'] ?? 'N/A'); ?></code></td>
        </tr>
    </table>

    <div class="section">
        <h3>🌐 Client-Side Browser URL Inspection (JavaScript)</h3>
        <div class="box" id="js-debug">
            Loading browser location details...
        </div>
    </div>
</div>

<script>
    window.addEventListener('DOMContentLoaded', () => {
        const box = document.getElementById('js-debug');
        box.innerHTML = `
            <strong>window.location.href:</strong> ${window.location.href}<br>
            <strong>window.location.pathname:</strong> ${window.location.pathname}<br>
            <strong>window.location.search:</strong> ${window.location.search || 'None'}<br>
            <strong>window.location.hash:</strong> ${window.location.hash || 'None'}<br>
            <strong>document.baseURI:</strong> ${document.baseURI}
        `;
    });
</script>
</body>
</html>
