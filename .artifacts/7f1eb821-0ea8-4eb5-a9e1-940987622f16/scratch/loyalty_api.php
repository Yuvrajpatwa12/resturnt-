<?php
/**
 * Loyalty & Rewards API (MySQLi Version) - Complete Production Script
 * Pure Real-time Database Version
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
$tenant_id = $_GET['tenant_id'] ?? 'startups_main';

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

        // --- 2. POINTS & STAMPS ---
        case 'get_points':
            $uid = strtolower(trim($_GET['user_id'] ?? ''));
            $tid = trim($_GET['tenant_id'] ?? $tenant_id);

            // Block guests and unauthenticated IDs from fetching global loyalty points
            if (empty($uid) || $uid === 'guest' || strpos($uid, 'guest_') === 0) {
                echo json_encode(["status" => "success", "user_id" => $uid, "points" => 0, "order_count" => 0]);
                break;
            }

            $stmt = $conn->prepare("SELECT points, order_count FROM customers WHERE LOWER(email) = LOWER(?) AND tenant_id = ?");
            $stmt->bind_param("ss", $uid, $tid);
            $stmt->execute();
            $row = $stmt->get_result()->fetch_assoc();
            echo json_encode([
                "status" => "success",
                "user_id" => $uid,
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

            $uid = strtolower(trim((string)$data->user_id));
            $tid = trim((string)$data->tenant_id);

            // Block guests from accumulating global loyalty points
            if (empty($uid) || $uid === 'guest' || strpos($uid, 'guest_') === 0) {
                echo json_encode(["status" => "error", "message" => "Guest user cannot accumulate global loyalty points. Please sync email first."]);
                exit;
            }

            $order_amount = isset($data->order_amount) ? (float)$data->order_amount : 0;
            $inc_stamps = isset($data->increment_stamps) ? (int)$data->increment_stamps : 1;

            $s_stmt = $conn->prepare("SELECT points_per_order_fixed, points_per_amount FROM loyalty_settings WHERE tenant_id = ?");
            $s_stmt->bind_param("s", $tid);
            $s_stmt->execute();
            $settings = $s_stmt->get_result()->fetch_assoc();

            $fixed = (int)($settings['points_per_order_fixed'] ?? 50);
            $factor = (float)($settings['points_per_amount'] ?? 0.05);

            $pts_to_add = isset($data->points) ? (int)$data->points : ($fixed + floor($order_amount * $factor));

            $stmt = $conn->prepare("INSERT INTO customers (email, tenant_id, points, order_count)
                                    VALUES (?, ?, ?, ?)
                                    ON DUPLICATE KEY UPDATE points = points + ?, order_count = order_count + ?");
            $stmt->bind_param("ssiiii", $uid, $tid, $pts_to_add, $inc_stamps, $pts_to_add, $inc_stamps);

            if ($stmt->execute()) {
                $notif_title = "Points Added!";
                $notif_msg = "You just earned $pts_to_add coins at this restaurant.";
                $notif_stmt = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type) VALUES (?, ?, ?, ?, 'points')");
                if ($notif_stmt) {
                    $notif_stmt->bind_param("ssss", $tid, $uid, $notif_title, $notif_msg);
                    $notif_stmt->execute();
                }

                echo json_encode(["status" => "success", "points_earned" => $pts_to_add, "message" => "Points updated"]);
            } else {
                echo json_encode(["status" => "error", "message" => $stmt->error]);
            }
            break;

        // --- 3. REWARDS ---
        case 'get_rewards':
            $res = $conn->query("SELECT * FROM redeemable_rewards WHERE tenant_id = '$tenant_id' AND is_active = 1 ORDER BY points_required ASC");
            echo json_encode(["status" => "success", "data" => $res ? $res->fetch_all(MYSQLI_ASSOC) : []]);
            break;

        case 'claim_reward':
            $json = file_get_contents('php://input');
            $data = !empty($json) ? json_decode($json) : null;
            $tid = trim($data->tenant_id ?? $_GET['tenant_id'] ?? $tenant_id);
            $uid = trim($data->user_id ?? $_GET['user_id'] ?? '');
            $rid = (int)($data->reward_id ?? $_GET['reward_id'] ?? 0);

            if (empty($tid) || empty($uid) || $rid <= 0) {
                echo json_encode(["status" => "error", "message" => "Invalid tenant, user or reward ID"]);
                break;
            }

            // Check reward details
            $r_stmt = $conn->prepare("SELECT * FROM redeemable_rewards WHERE id = ? AND tenant_id = ?");
            if ($r_stmt) {
                $r_stmt->bind_param("is", $rid, $tid);
                $r_stmt->execute();
                $reward = $r_stmt->get_result()->fetch_assoc();
                $r_stmt->close();
            }

            if (empty($reward)) {
                echo json_encode(["status" => "error", "message" => "Reward not found"]);
                break;
            }

            $ptsReq = (int)($reward['points_required'] ?? 0);

            // Check user points
            $u_stmt = $conn->prepare("SELECT points FROM customers WHERE LOWER(email) = LOWER(?) AND tenant_id = ?");
            $userPts = 0;
            if ($u_stmt) {
                $u_stmt->bind_param("ss", $uid, $tid);
                $u_stmt->execute();
                $u_res = $u_stmt->get_result()->fetch_assoc();
                $userPts = (int)($u_res['points'] ?? 0);
                $u_stmt->close();
            }

            if ($userPts < $ptsReq) {
                echo json_encode(["status" => "error", "message" => "Insufficient points ($userPts / $ptsReq required)"]);
                break;
            }

            // Deduct points safely using standard ANSI SQL
            $deduct_stmt = $conn->prepare("UPDATE customers SET points = CASE WHEN points >= ? THEN points - ? ELSE 0 END WHERE LOWER(email) = LOWER(?) AND tenant_id = ?");
            if ($deduct_stmt) {
                $deduct_stmt->bind_param("iiss", $ptsReq, $ptsReq, $uid, $tid);
                $deduct_stmt->execute();
                $deduct_stmt->close();
            }

            // Generate claim code
            $code = (string)mt_rand(10000, 99999);

            // Insert into reward_claims
            $claim_stmt = $conn->prepare("INSERT INTO reward_claims (tenant_id, user_id, reward_id, claim_code, status) VALUES (?, ?, ?, ?, 'Pending')");
            if ($claim_stmt) {
                $claim_stmt->bind_param("ssis", $tid, $uid, $rid, $code);
                $claim_stmt->execute();
                $claim_stmt->close();
            }

            echo json_encode([
                "status" => "success",
                "message" => "Reward claimed successfully!",
                "claim_code" => $code
            ]);
            break;

        case 'add_reward':
            $data = json_decode(file_get_contents('php://input'));
            $stmt = $conn->prepare("INSERT INTO redeemable_rewards (tenant_id, title, points_required, image_url, description) VALUES (?, ?, ?, ?, ?)");
            $stmt->bind_param("ssiss", $data->tenant_id, $data->title, $data->points_required, $data->image_url, $data->description);
            $stmt->execute();
            echo json_encode(["status" => "success"]);
            break;

        case 'update_reward':
        case 'edit_reward':
            $data = json_decode(file_get_contents('php://input'));
            $id = (int)($data->id ?? $_GET['id'] ?? 0);
            $title = $data->title ?? '';
            $pts = (int)($data->points_required ?? 100);
            $img = $data->image_url ?? '';

            if ($id > 0 && !empty($title)) {
                $stmt = $conn->prepare("UPDATE redeemable_rewards SET title = ?, points_required = ?, image_url = ? WHERE id = ?");
                $stmt->bind_param("sisi", $title, $pts, $img, $id);
                $stmt->execute();
                $stmt->close();
                echo json_encode(["status" => "success", "message" => "Reward updated"]);
            } else {
                echo json_encode(["status" => "error", "message" => "Missing reward ID or title"]);
            }
            break;

        case 'delete_reward':
            $id = (int)($_GET['id'] ?? 0);
            $conn->query("DELETE FROM redeemable_rewards WHERE id = $id");
            echo json_encode(["status" => "success"]);
            break;

        // --- 4. MYSTERY BOX ADMIN MANAGEMENT ---
        case 'get_mystery_box':
            $stmt = $conn->prepare("SELECT id, tenant_id, reward_name, reward_name AS title, reward_name AS prize_name, probability, image_url, created_at FROM mystery_box_config WHERE tenant_id = ? ORDER BY id DESC");
            if ($stmt) {
                $stmt->bind_param("s", $tenant_id);
                $stmt->execute();
                $res = $stmt->get_result();
                echo json_encode(["status" => "success", "data" => $res ? $res->fetch_all(MYSQLI_ASSOC) : []]);
            } else {
                echo json_encode(["status" => "success", "data" => []]);
            }
            break;

        case 'save_mystery_box':
        case 'add_mystery_prize':
            $data = json_decode(file_get_contents('php://input'));
            $title = $data->reward_name ?? $data->prize_name ?? $data->title ?? '';
            if (!$data || empty($data->tenant_id) || empty($title)) {
                echo json_encode(["status" => "error", "message" => "Invalid prize payload"]);
                exit;
            }
            $stmt = $conn->prepare("INSERT INTO mystery_box_config (tenant_id, reward_name, probability, image_url) VALUES (?, ?, ?, ?)");
            if ($stmt) {
                $prob = (float)($data->probability ?? 10);
                $img = $data->image_url ?? '';
                $stmt->bind_param("ssds", $data->tenant_id, $title, $prob, $img);
                if ($stmt->execute()) {
                    echo json_encode(["status" => "success", "message" => "Prize added"]);
                } else {
                    echo json_encode(["status" => "error", "message" => "Execute failed: " . $stmt->error]);
                }
                $stmt->close();
            } else {
                echo json_encode(["status" => "error", "message" => "Prepare failed: " . $conn->error]);
            }
            break;

        case 'delete_mystery_prize':
            $id = (int)($_GET['id'] ?? 0);
            $conn->query("DELETE FROM mystery_box_config WHERE id = $id");
            echo json_encode(["status" => "success", "message" => "Prize removed"]);
            break;

        // --- 5. OPEN MYSTERY BOX (CUSTOMER UNBOXING) ---
        case 'open_mystery_box':
            $uid = $_GET['user_id'] ?? 'guest';
            $userName = trim($_GET['user_name'] ?? '');

            // Automatically sync customer display name if passed
            if (!empty($userName) && !empty($uid) && $uid !== 'guest') {
                try {
                    $cust_stmt = $conn->prepare("INSERT INTO customers (email, tenant_id, name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE name = ?");
                    if ($cust_stmt) {
                        $cust_stmt->bind_param("ssss", $uid, $tenant_id, $userName, $userName);
                        $cust_stmt->execute();
                        $cust_stmt->close();
                    }
                } catch (Throwable $e) {}
            }

            // 1. Check if user already claimed today
            if (!empty($uid) && $uid !== 'guest') {
                $check_stmt = $conn->prepare("SELECT COUNT(*) as count FROM reward_claims WHERE tenant_id = ? AND user_id = ? AND DATE(created_at) = CURDATE()");
                if ($check_stmt) {
                    $check_stmt->bind_param("ss", $tenant_id, $uid);
                    $check_stmt->execute();
                    $check_res = $check_stmt->get_result()->fetch_assoc();
                    $today_count = (int)($check_res['count'] ?? 0);
                    $check_stmt->close();

                    if ($today_count > 0) {
                        echo json_encode([
                            "status" => "limit_reached",
                            "message" => "Daily limit reached! You have already claimed today's Mystery Box. Come back tomorrow!"
                        ]);
                        exit;
                    }
                }
            }

            // 2. Select prize from database
            $stmt = $conn->prepare("SELECT id, tenant_id, reward_name, reward_name AS title, reward_name AS prize_name, probability, image_url, created_at FROM mystery_box_config WHERE tenant_id = ?");
            if ($stmt) {
                $stmt->bind_param("s", $tenant_id);
                $stmt->execute();
                $items = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            } else {
                $items = [];
            }

            if (empty($items)) {
                echo json_encode([
                    "status" => "error",
                    "message" => "No mystery box prizes configured by admin yet. Please check back later!"
                ]);
                exit;
            }

            $totalProb = 0;
            foreach ($items as $it) {
                $totalProb += (float)($it['probability'] ?? 1);
            }
            if ($totalProb <= 0) $totalProb = 100;

            $rand = (mt_rand(0, 10000) / 100);
            $current = 0;
            $wonItem = $items[0];
            foreach ($items as $item) {
                $current += (float)($item['probability'] ?? 1);
                if ($rand <= $current) {
                    $wonItem = $item;
                    break;
                }
            }

            $code = (string)mt_rand(10000, 99999);

            // 3. Insert claim record with 'pending' status
            try {
                $rid = (int)($wonItem['id'] ?? 0);
                $claim_stmt = $conn->prepare("INSERT INTO reward_claims (tenant_id, user_id, reward_id, claim_code, status) VALUES (?, ?, ?, ?, 'Pending')");
                if ($claim_stmt) {
                    $claim_stmt->bind_param("ssis", $tenant_id, $uid, $rid, $code);
                    $claim_stmt->execute();
                    $claim_stmt->close();
                }
            } catch (Throwable $ex) {
                // Ignore schema mismatch
            }

            echo json_encode([
                "status" => "success",
                "data" => $wonItem,
                "claim_code" => $code
            ]);
            break;

        // --- 6. REWARD CLAIMS & REDEMPTIONS (ISOLATED BY USER) ---
        case 'get_admin_claims':
            $baseSelect = "SELECT c.*, COALESCE(m.reward_name, r.title, 'Mystery Prize') AS reward_name, COALESCE(m.reward_name, r.title, 'Mystery Prize') AS reward_title, COALESCE(cust.name, cust.email, NULL) AS user_name FROM reward_claims c LEFT JOIN mystery_box_config m ON c.reward_id = m.id LEFT JOIN redeemable_rewards r ON c.reward_id = r.id LEFT JOIN customers cust ON c.user_id = cust.email AND c.tenant_id = cust.tenant_id ";
            $stmt = $conn->prepare($baseSelect . "WHERE c.tenant_id = ? ORDER BY c.id DESC");
            if ($stmt) {
                $stmt->bind_param("s", $tenant_id);
                $stmt->execute();
                $res = $stmt->get_result();
                $rows = $res ? $res->fetch_all(MYSQLI_ASSOC) : [];
                foreach ($rows as &$r) {
                    $st = strtolower(trim($r['status'] ?? ''));
                    $red = trim($r['redeemed_at'] ?? '');
                    if (empty($st) || $st === 'null') {
                        $r['status'] = (!empty($red) && $red !== 'null') ? 'redeemed' : 'Pending';
                    }
                }
                echo json_encode(["status" => "success", "data" => $rows]);
            } else {
                echo json_encode(["status" => "success", "data" => []]);
            }
            break;

        case 'get_all_claims':
        case 'get_claims':
            $uidFilter = trim($_GET['user_id'] ?? '');
            $guestFilter = trim($_GET['guest_id'] ?? '');

            // Ignore generic 'guest' literal string
            if (strtolower($uidFilter) === 'guest') $uidFilter = '';
            if (strtolower($guestFilter) === 'guest') $guestFilter = '';

            // If no valid user/guest filter was provided, return empty list (prevents leaking all tenant claims to customers)
            if (empty($uidFilter) && empty($guestFilter)) {
                echo json_encode(["status" => "success", "data" => []]);
                break;
            }

            $baseSelect = "SELECT c.*, COALESCE(m.reward_name, r.title, 'Mystery Prize') AS reward_name, COALESCE(m.reward_name, r.title, 'Mystery Prize') AS reward_title FROM reward_claims c LEFT JOIN mystery_box_config m ON c.reward_id = m.id LEFT JOIN redeemable_rewards r ON c.reward_id = r.id ";

            if (!empty($uidFilter) && !empty($guestFilter) && $uidFilter !== $guestFilter) {
                $stmt = $conn->prepare($baseSelect . "WHERE c.tenant_id = ? AND (c.user_id = ? OR c.user_id = ?) ORDER BY c.id DESC");
                if ($stmt) {
                    $stmt->bind_param("sss", $tenant_id, $uidFilter, $guestFilter);
                    $stmt->execute();
                    $res = $stmt->get_result();
                    $rows = $res ? $res->fetch_all(MYSQLI_ASSOC) : [];
                    foreach ($rows as &$r) {
                        $st = strtolower(trim($r['status'] ?? ''));
                        $red = trim($r['redeemed_at'] ?? '');
                        if (empty($st) || $st === 'null') {
                            $r['status'] = (!empty($red) && $red !== 'null') ? 'redeemed' : 'Pending';
                        }
                    }
                    echo json_encode(["status" => "success", "data" => $rows]);
                } else {
                    echo json_encode(["status" => "success", "data" => []]);
                }
            } else {
                $targetId = !empty($uidFilter) ? $uidFilter : $guestFilter;
                $stmt = $conn->prepare($baseSelect . "WHERE c.tenant_id = ? AND c.user_id = ? ORDER BY c.id DESC");
                if ($stmt) {
                    $stmt->bind_param("ss", $tenant_id, $targetId);
                    $stmt->execute();
                    $res = $stmt->get_result();
                    $rows = $res ? $res->fetch_all(MYSQLI_ASSOC) : [];
                    foreach ($rows as &$r) {
                        $st = strtolower(trim($r['status'] ?? ''));
                        $red = trim($r['redeemed_at'] ?? '');
                        if (empty($st) || $st === 'null') {
                            $r['status'] = (!empty($red) && $red !== 'null') ? 'redeemed' : 'Pending';
                        }
                    }
                    echo json_encode(["status" => "success", "data" => $rows]);
                } else {
                    echo json_encode(["status" => "success", "data" => []]);
                }
            }
            break;

        case 'verify_claim_code':
        case 'lookup_claim':
            $claimCode = trim($_GET['claim_code'] ?? $_POST['claim_code'] ?? '');
            if (empty($claimCode)) {
                $rawInput = file_get_contents('php://input');
                $data = !empty($rawInput) ? json_decode($rawInput) : null;
                $claimCode = trim($data->claim_code ?? '');
            }

            if (empty($claimCode)) {
                echo json_encode(["status" => "error", "message" => "Please enter a claim code"]);
                break;
            }

            $cleanCode = trim($claimCode);
            $mysCode = "MYS-" . ltrim($cleanCode, 'MYS-');
            $rawCode = str_replace("MYS-", "", $cleanCode);

            $sql = "SELECT c.*,
                    COALESCE(m.reward_name, r.title, 'Mystery Prize') AS reward_title,
                    COALESCE(m.reward_name, r.title, 'Mystery Prize') AS reward_name,
                    COALESCE(cust.name, cust.email, c.user_id) AS user_name,
                    cust.email AS user_email
                    FROM reward_claims c
                    LEFT JOIN mystery_box_config m ON c.reward_id = m.id
                    LEFT JOIN redeemable_rewards r ON c.reward_id = r.id
                    LEFT JOIN customers cust ON (c.user_id = cust.email OR c.user_id = cust.name) AND c.tenant_id = cust.tenant_id
                    WHERE (LOWER(c.claim_code) = LOWER(?) OR LOWER(c.claim_code) = LOWER(?) OR LOWER(c.claim_code) = LOWER(?) OR c.id = ?)
                    AND c.tenant_id = ?
                    ORDER BY c.id DESC LIMIT 1";

            $targetId = is_numeric($cleanCode) ? (int)$cleanCode : 0;
            $stmt = $conn->prepare($sql);
            if ($stmt) {
                $stmt->bind_param("sssis", $cleanCode, $mysCode, $rawCode, $targetId, $tenant_id);
                $stmt->execute();
                $claim = $stmt->get_result()->fetch_assoc();
                $stmt->close();

                if ($claim) {
                    $st = strtolower(trim($claim['status'] ?? ''));
                    $red = trim($claim['redeemed_at'] ?? '');
                    if (empty($st) || $st === 'null') {
                        $claim['status'] = (!empty($red) && $red !== 'null') ? 'redeemed' : 'Pending';
                    }
                    echo json_encode(["status" => "success", "data" => $claim]);
                } else {
                    echo json_encode(["status" => "error", "message" => "Invalid or non-existent claim code '$claimCode'!"]);
                }
            } else {
                echo json_encode(["status" => "error", "message" => "SQL prepare error"]);
            }
            break;

        case 'redeem_claim':
        case 'update_claim_status':
            $rawInput = file_get_contents('php://input');
            $data = !empty($rawInput) ? json_decode($rawInput) : null;

            $claimCode = trim($data->claim_code ?? $_GET['claim_code'] ?? '');
            $cid = (int)($data->id ?? $_GET['id'] ?? 0);
            $newStatus = trim($data->status ?? $_GET['status'] ?? 'redeemed');
            if (empty($newStatus)) {
                $newStatus = 'redeemed';
            }

            if (empty($claimCode) && $cid <= 0) {
                echo json_encode(["status" => "error", "message" => "Missing claim_code or ID"]);
                break;
            }

            $cleanCode = trim($claimCode);
            $mysCode = "MYS-" . ltrim($cleanCode, 'MYS-');
            $rawCode = str_replace("MYS-", "", $cleanCode);

            // First verify if the claim record exists for this tenant
            $checkSql = "SELECT id, claim_code, status FROM reward_claims WHERE (LOWER(claim_code) = LOWER(?) OR LOWER(claim_code) = LOWER(?) OR LOWER(claim_code) = LOWER(?) OR id = ?) AND tenant_id = ? LIMIT 1";
            $checkStmt = $conn->prepare($checkSql);
            $existingClaim = null;
            if ($checkStmt) {
                $checkStmt->bind_param("sssis", $cleanCode, $mysCode, $rawCode, $cid, $tenant_id);
                $checkStmt->execute();
                $existingClaim = $checkStmt->get_result()->fetch_assoc();
                $checkStmt->close();
            }

            if (!$existingClaim) {
                echo json_encode(["status" => "error", "message" => "Invalid or non-existent claim code '$claimCode'!"]);
                break;
            }

            $targetId = (int)$existingClaim['id'];
            $updateStmt = $conn->prepare("UPDATE reward_claims SET status = ?, redeemed_at = NOW() WHERE id = ?");
            if ($updateStmt) {
                $updateStmt->bind_param("si", $newStatus, $targetId);
                $updateStmt->execute();
                $updateStmt->close();
                echo json_encode(["status" => "success", "message" => "Reward claim code '$cleanCode' REDEEMED successfully!"]);
            } else {
                echo json_encode(["status" => "error", "message" => "Failed to update claim status"]);
            }
            break;

        default:
            echo json_encode(["status" => "error", "message" => "Action '$action' unknown"]);
            break;
    }
} catch (Throwable $e) {
    echo json_encode(["status" => "error", "message" => "API Exception: " . $e->getMessage()]);
}

$conn->close();
?>
