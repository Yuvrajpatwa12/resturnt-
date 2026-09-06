<?php
/**
 * Loyalty & Rewards API (MySQLi Version) - V2 (Unified Customers Table)
 * Optimized for Localhost (CORS) and Hostinger stability.
 */

// --- 1. CORS Headers ---
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

// --- 2. Database Connection ---
require_once 'db_config.php';

if ($conn->connect_error) {
    die(json_encode(["status" => "error", "message" => "Connection failed: " . $conn->connect_error]));
}

$action = $_GET['action'] ?? '';
$tenant_id = $_GET['tenant_id'] ?? '';

try {
    switch ($action) {
        // --- 1. SETTINGS ---
        case 'get_settings':
            $stmt = $conn->prepare("SELECT * FROM loyalty_settings WHERE tenant_id = ?");
            $stmt->bind_param("s", $tenant_id);
            $stmt->execute();
            $settings = $stmt->get_result()->fetch_assoc();
            echo json_encode(["status" => "success", "data" => $settings ?: [
                "points_per_order_fixed" => 50,
                "points_per_amount" => 0.05,
                "group_join_bonus" => 200,
                "mystery_box_enabled" => 1,
                "min_redeem_points" => 100
            ]]);
            break;

        case 'update_settings':
            $json = file_get_contents('php://input');
            $data = json_decode($json);

            if (!$data || empty($data->tenant_id)) {
                echo json_encode(["status" => "error", "message" => "Missing tenant_id in request."]);
                exit;
            }

            $tid = $data->tenant_id;
            $fixed = (int)$data->points_per_order_fixed;
            $amt = (float)$data->points_per_amount;
            $group = (int)$data->group_join_bonus;
            $mbox = (int)$data->mystery_box_enabled;
            $min = (int)$data->min_redeem_points;

            $stmt = $conn->prepare("INSERT INTO loyalty_settings (tenant_id, points_per_order_fixed, points_per_amount, group_join_bonus, mystery_box_enabled, min_redeem_points)
                                    VALUES (?, ?, ?, ?, ?, ?)
                                    ON DUPLICATE KEY UPDATE
                                    points_per_order_fixed = ?, points_per_amount = ?, group_join_bonus = ?, mystery_box_enabled = ?, min_redeem_points = ?");

            $stmt->bind_param("sidiiidiiii", $tid, $fixed, $amt, $group, $mbox, $min, $fixed, $amt, $group, $mbox, $min);

            if ($stmt->execute()) {
                echo json_encode(["status" => "success", "message" => "Settings successfully saved."]);
            } else {
                echo json_encode(["status" => "error", "message" => "Execute error: " . $stmt->error]);
            }
            break;

        // --- 2. POINTS & STAMPS (Unified Customers Table) ---
        case 'get_points':
            $uid = $_GET['user_id'] ?? '';
            $tid = $_GET['tenant_id'] ?? '';

            // Unified fetch from customers table
            $stmt = $conn->prepare("SELECT points, order_count FROM customers WHERE email = ? AND tenant_id = ?");
            $stmt->bind_param("ss", $uid, $tid);
            $stmt->execute();
            $row = $stmt->get_result()->fetch_assoc();
            echo json_encode([
                "status" => "success",
                "points" => (int)($row['points'] ?? 0),
                "order_count" => (int)($row['order_count'] ?? 0)
            ]);
            break;

        case 'add_points':
            $data = json_decode(file_get_contents('php://input'));
            if (!$data || empty($data->user_id) || empty($data->tenant_id)) {
                echo json_encode(["status" => "error", "message" => "Invalid data"]);
                exit;
            }

            $uid = (string)$data->user_id;
            $tid = (string)$data->tenant_id;
            $order_amount = isset($data->order_amount) ? (float)$data->order_amount : 0;
            $inc_stamps = isset($data->increment_stamps) ? (int)$data->increment_stamps : 1;

            // 1. Fetch current loyalty settings for calculation
            $s_stmt = $conn->prepare("SELECT points_per_order_fixed, points_per_amount FROM loyalty_settings WHERE tenant_id = ?");
            $s_stmt->bind_param("s", $tid);
            $s_stmt->execute();
            $settings = $s_stmt->get_result()->fetch_assoc();

            $fixed = (int)($settings['points_per_order_fixed'] ?? 50);
            $factor = (float)($settings['points_per_amount'] ?? 0.05);

            // 2. Calculate points
            $pts_to_add = isset($data->points) ? (int)$data->points : ($fixed + floor($order_amount * $factor));

            // 3. Update unified customers table
            $stmt = $conn->prepare("INSERT INTO customers (email, tenant_id, points, order_count)
                                    VALUES (?, ?, ?, ?)
                                    ON DUPLICATE KEY UPDATE points = points + ?, order_count = order_count + ?");
            $stmt->bind_param("ssiiii", $uid, $tid, $pts_to_add, $inc_stamps, $pts_to_add, $inc_stamps);

            if ($stmt->execute()) {
                // Trigger Notification
                $notif_title = "Points Added!";
                $notif_msg = "You just earned $pts_to_add coins at this restaurant.";
                $notif_stmt = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type) VALUES (?, ?, ?, ?, 'points')");
                $notif_stmt->bind_param("ssss", $tid, $uid, $notif_title, $notif_msg);
                $notif_stmt->execute();

                echo json_encode(["status" => "success", "points_earned" => $pts_to_add, "message" => "Points updated"]);
            } else {
                echo json_encode(["status" => "error", "message" => $stmt->error]);
            }
            break;

        // --- 3. REWARDS ---
        case 'get_rewards':
            $res = $conn->query("SELECT * FROM redeemable_rewards WHERE tenant_id = '$tenant_id' AND is_active = 1 ORDER BY points_required ASC");
            echo json_encode(["status" => "success", "data" => $res->fetch_all(MYSQLI_ASSOC)]);
            break;

        case 'add_reward':
            $data = json_decode(file_get_contents('php://input'));
            $stmt = $conn->prepare("INSERT INTO redeemable_rewards (tenant_id, title, points_required, image_url, description) VALUES (?, ?, ?, ?, ?)");
            $stmt->bind_param("ssiss", $data->tenant_id, $data->title, $data->points_required, $data->image_url, $data->description);
            $stmt->execute();
            echo json_encode(["status" => "success"]);
            break;

        // --- 4. MYSTERY BOX ---
        case 'open_mystery_box':
            $res = $conn->query("SELECT * FROM mystery_box_config WHERE tenant_id = '$tenant_id'");
            $items = $res->fetch_all(MYSQLI_ASSOC);
            if (empty($items)) exit(json_encode(["status" => "error", "message" => "No prizes configured"]));

            $totalProb = array_sum(array_column($items, 'probability'));
            $rand = mt_rand(0, $totalProb * 100) / 100;
            $current = 0; $wonItem = $items[0];
            foreach ($items as $item) { $current += $item['probability']; if ($rand <= $current) { $wonItem = $item; break; } }

            $code = "MYS-" . strtoupper(substr(md5(time()), 0, 5));
            $uid = $_GET['user_id'];
            $stmt = $conn->prepare("INSERT INTO reward_claims (tenant_id, user_id, reward_id, claim_code) VALUES (?, ?, 0, ?)");
            $stmt->bind_param("sss", $tenant_id, $uid, $code);
            $stmt->execute();
            echo json_encode(["status" => "success", "data" => $wonItem, "claim_code" => $code]);
            break;

        default:
            echo json_encode(["status" => "error", "message" => "Invalid action: $action"]);
            break;
    }
} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => "API Exception: " . $e->getMessage()]);
}
$conn->close();
?>
