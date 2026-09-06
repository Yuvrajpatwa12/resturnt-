<?php
/**
 * get_public_profile.php
 * Returns public data (Name, Gender, Table) for any user by their ID/Email.
 */
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once 'db_config.php';

if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Database connection failed"]));
}

$target_id = $_GET['target_id'] ?? '';
$my_id = $_GET['my_id'] ?? '';
$tid = $_GET['tenant_id'] ?? '';

if (empty($target_id) || empty($tid)) {
    echo json_encode(["status" => "error", "message" => "Missing data"]);
    exit;
}

try {
    // 1. Fetch Basic Info
    $stmt = $conn->prepare("SELECT name, gender, points, order_count FROM customers WHERE email = ? AND tenant_id = ?");
    $stmt->bind_param("ss", $target_id, $tid);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();

    if (!$user) {
        echo json_encode(["status" => "error", "message" => "User not found"]);
        exit;
    }

    // 2. Fetch Current Table from Presence
    $p_stmt = $conn->prepare("SELECT table_number FROM restaurant_presence WHERE user_id = ? AND tenant_id = ? LIMIT 1");
    $p_stmt->bind_param("ss", $target_id, $tid);
    $p_stmt->execute();
    $presence = $p_stmt->get_result()->fetch_assoc();
    $user['current_table'] = $presence ? $presence['table_number'] : "Not Seated";

    // 3. Fetch Relationship Status
    $f_stmt = $conn->prepare("SELECT
        (SELECT COUNT(*) FROM user_follows WHERE follower_id = ? AND following_id = ? AND tenant_id = ?) as is_following,
        (SELECT COUNT(*) FROM user_follows WHERE follower_id = ? AND following_id = ? AND tenant_id = ?) as follows_me");
    $f_stmt->bind_param("ssssss", $my_id, $target_id, $tid, $target_id, $my_id, $tid);
    $f_stmt->execute();
    $rel = $f_stmt->get_result()->fetch_assoc();

    $user['is_following'] = (int)$rel['is_following'] > 0;
    $user['follows_me'] = (int)$rel['follows_me'] > 0;

    echo json_encode([
        "status" => "success",
        "data" => $user
    ]);

} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}

$conn->close();
?>
