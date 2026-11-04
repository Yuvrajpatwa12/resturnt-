
<?php
/**
 * Temporary Super Admin credential verifier.
 * Requires HTTPS and SUPER_ADMIN_TEST_ACCESS_KEY; never creates a login session.
 */
if (PHP_SAPI === 'cli') {
    fwrite(STDERR, "Run this verifier through HTTPS in a browser.\n");
    exit(2);
}

$https = !empty($_SERVER['HTTPS']) && strtolower((string)$_SERVER['HTTPS']) !== 'off';
if (!$https) {
    http_response_code(403);
    exit('HTTPS is required.');
}

$accessKey = (string)getenv('SUPER_ADMIN_TEST_ACCESS_KEY');
if (strlen($accessKey) < 32) {
    http_response_code(503);
    exit('The temporary login verifier is not configured.');
}

header('Content-Type: text/html; charset=UTF-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');

session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => true,
    'httponly' => true,
    'samesite' => 'Strict'
]);
session_start();

if (empty($_SESSION['super_admin_test_csrf'])) {
    $_SESSION['super_admin_test_csrf'] = bin2hex(random_bytes(32));
}

$message = '';
$messageType = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $providedKey = (string)($_POST['access_key'] ?? '');
    $csrf = (string)($_POST['csrf'] ?? '');
    $email = strtolower(trim((string)($_POST['email'] ?? '')));
    $pin = trim((string)($_POST['pin'] ?? ''));
    $validCsrf = hash_equals(
        (string)$_SESSION['super_admin_test_csrf'],
        $csrf
    );

    if (!$validCsrf || !hash_equals($accessKey, $providedKey)) {
        http_response_code(403);
        $message = 'Access denied. Check the private access key and reload the page.';
        $messageType = 'error';
    } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL) ||
        strlen($email) > 255 || strlen($pin) < 4 || strlen($pin) > 64) {
        $message = 'Enter a valid email and a PIN between 4 and 64 characters.';
        $messageType = 'error';
    } elseif ((int)($_SESSION['super_admin_test_attempts'] ?? 0) >= 5) {
        http_response_code(429);
        $message = 'Too many attempts in this browser session. Close the page and start a new session.';
        $messageType = 'error';
    } else {
        $_SESSION['super_admin_test_attempts'] =
            (int)($_SESSION['super_admin_test_attempts'] ?? 0) + 1;
        try {
            mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
            require_once __DIR__ . DIRECTORY_SEPARATOR . 'db_config.php';
            $stmt = $conn->prepare(
                'SELECT password_hash FROM super_admins
                 WHERE LOWER(email) = ? LIMIT 2'
            );
            $stmt->bind_param('s', $email);
            $stmt->execute();
            $result = $stmt->get_result();

            if ($result->num_rows === 1) {
                $storedHash = (string)$result->fetch_assoc()['password_hash'];
                $demoHashes = [
                    hash('sha256', 'patwa'),
                    hash('sha256', '123456'),
                    hash('sha256', 'admin')
                ];
                $matches = !in_array($storedHash, $demoHashes, true) &&
                    (password_verify($pin, $storedHash) ||
                     hash_equals($storedHash, hash('sha256', $pin)));
            } else {
                $matches = false;
            }

            $stmt->close();
            $stmt = null;
            if ($matches) {
                $message = 'PASS: The database contains one matching Super Admin email and the PIN is correct.';
                $messageType = 'success';
            } else {
                $message = 'FAIL: The email/PIN did not match one unique eligible Super Admin account.';
                $messageType = 'error';
            }
        } catch (Throwable $e) {
            error_log('Temporary Super Admin credential check failed: ' . $e->getMessage());
            http_response_code(500);
            $message = 'The database check failed. Ask the site administrator to inspect the PHP error log.';
            $messageType = 'error';
        } finally {
            $pin = '';
            $email = '';
            if (isset($stmt) && $stmt instanceof mysqli_stmt) {
                $stmt->close();
            }
        }
    }

    $_SESSION['super_admin_test_csrf'] = bin2hex(random_bytes(32));
    unset($providedKey, $pin, $email);
}

function testPageEscape($value) {
    return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Temporary Super Admin Login Check</title>
    <style>
        body { font: 16px system-ui, sans-serif; max-width: 520px; margin: 48px auto; padding: 0 18px; color: #172033; }
        label { display: block; margin: 16px 0 6px; font-weight: 600; }
        input { box-sizing: border-box; width: 100%; padding: 11px; border: 1px solid #aab3c2; border-radius: 6px; }
        button { margin-top: 20px; padding: 11px 18px; border: 0; border-radius: 6px; background: #174ea6; color: white; font-weight: 700; }
        .notice { padding: 12px; border-radius: 6px; background: #eef3fb; }
        .success { color: #146c2e; } .error { color: #a32121; }
    </style>
</head>
<body>
    <h1>Super Admin login check</h1>
    <p class="notice">Temporary verifier: it checks the database email/PIN only and does not create an app login session. Remove this file after testing.</p>
    <?php if ($message !== ''): ?>
        <p class="<?= testPageEscape($messageType) ?>" role="status"><?= testPageEscape($message) ?></p>
    <?php endif; ?>
    <form method="post" autocomplete="off">
        <input type="hidden" name="csrf" value="<?= testPageEscape($_SESSION['super_admin_test_csrf']) ?>">
        <label for="access_key">Private test access key</label>
        <input id="access_key" name="access_key" type="password" required autocomplete="off">
        <label for="email">Super Admin email</label>
        <input id="email" name="email" type="email" required maxlength="255" autocomplete="off">
        <label for="pin">Super Admin PIN</label>
        <input id="pin" name="pin" type="password" required minlength="4" maxlength="64" autocomplete="new-password">
        <button type="submit">Verify credentials</button>
    </form>
</body>
</html>
