<?php
/**
 * Push Notifier Helper (Production FCM V1)
 * Handles Google OAuth2 Auth and sends real-time alerts.
 */

require_once 'db_config.php';

function getGoogleAccessToken($serviceAccountPath) {
    $json = file_get_contents($serviceAccountPath);
    $data = json_decode($json, true);


    $privateKey = $data['private_key'];
    $clientEmail = $data['client_email'];

    $header = json_encode(['alg' => 'RS256', 'typ' => 'JWT']);
    $now = time();
    $payload = json_encode([
        'iss' => $clientEmail,
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => 'https://oauth2.googleapis.com/token',
        'exp' => $now + 3600,
        'iat' => $now
    ]);

    $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
    $base64UrlPayload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($payload));

    openssl_sign($base64UrlHeader . "." . $base64UrlPayload, $signature, $privateKey, OPENSSL_ALGO_SHA256);
    $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));

    $jwt = $base64UrlHeader . "." . $base64UrlPayload . "." . $base64UrlSignature;

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, 'https://oauth2.googleapis.com/token');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' . $jwt);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);

    $result = curl_exec($ch);
    curl_close($ch);

    $resData = json_decode($result, true);
    return $resData['access_token'] ?? null;
}

function sendPushNotification($token, $title, $body, $data = []) {
    $serviceAccountPath = __DIR__ . '/service-account.json';
    if (!file_exists($serviceAccountPath)) return false;

    $accessToken = getGoogleAccessToken($serviceAccountPath);
    if (!$accessToken) return false;

    // Get Project ID from JSON
    $acc = json_decode(file_get_contents($serviceAccountPath), true);
    $projectId = $acc['project_id'];

    $url = "https://fcm.googleapis.com/v1/projects/$projectId/messages:send";

    $payload = [
        'message' => [
            'token' => $token,
            'notification' => [
                'title' => $title,
                'body' => $body
            ],
            'data' => array_map('strval', $data) // FCM V1 requires string values in data
        ]
    ];

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $accessToken,
        'Content-Type: application/json'
    ]);

    $result = curl_exec($ch);
    curl_close($ch);

    return $result;
}

function notifyUser($uid, $tid, $title, $body, $type, $sender_id = null) {
    global $conn;

    $stmt = $conn->prepare("SELECT fcm_token FROM customers WHERE email = ? AND tenant_id = ?");
    $stmt->bind_param("ss", $uid, $tid);
    $stmt->execute();
    $res = $stmt->get_result();

    if ($row = $res->fetch_assoc()) {
        $token = $row['fcm_token'];
        if (!empty($token)) {
            sendPushNotification($token, $title, $body, [
                'type' => $type,
                'sender_id' => $sender_id
            ]);
        }
    }
}
?>
