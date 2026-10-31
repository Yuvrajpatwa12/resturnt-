<?php
/**
 * Multiplayer Tap War Squad API
 * Handles squad creation, invites, presence verification, tap batching, and game state.
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once 'db_config.php';

if ($conn->connect_error) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Database connection failed"]);
    exit;
}

// Ensure required tables exist
$conn->query("CREATE TABLE IF NOT EXISTS rate_limits (
    user_id VARCHAR(100) NOT NULL,
    action_key VARCHAR(100) NOT NULL,
    window_start DATETIME NOT NULL,
    COUNT INT NOT NULL DEFAULT 1,
    PRIMARY KEY (user_id, action_key),
    UNIQUE KEY uniq_user_action (user_id, action_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

$conn->query("CREATE TABLE IF NOT EXISTS game_squads (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    table_id INT NOT NULL,
    created_by_user_id VARCHAR(100) NOT NULL,
    game_type VARCHAR(50) NOT NULL DEFAULT 'tap_war',
    status VARCHAR(50) NOT NULL DEFAULT 'Forming', -- Forming, Ready, InProgress, Completed, Cancelled, Expired
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at DATETIME DEFAULT NULL,
    start_at DATETIME DEFAULT NULL,
    max_players INT NOT NULL DEFAULT 4
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

$conn->query("CREATE TABLE IF NOT EXISTS game_squad_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    squad_id INT NOT NULL,
    user_id VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Invited', -- Invited, Joined, Declined, Left
    invited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    responded_at DATETIME DEFAULT NULL,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_squad_user (squad_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

$conn->query("CREATE TABLE IF NOT EXISTS game_squad_scores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    squad_id INT NOT NULL,
    user_id VARCHAR(100) NOT NULL,
    tap_count INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_score_squad_user (squad_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

// Rate limiting helper with atomic FOR UPDATE transaction and probabilistic cleanup (1% chance)
function checkRateLimit($conn, $userId, $actionKey, $maxPerWindow, $windowSeconds) {
    if (empty($userId)) {
        error_log("Rate limit error: empty user_id provided (fail closed).");
        return false; // Fail closed
    }

    // Probabilistic cleanup (only ~1% of calls) to reduce database load
    if (mt_rand(1, 100) === 1) {
        @$conn->query("DELETE FROM rate_limits WHERE window_start < (NOW() - INTERVAL 5 MINUTE)");
    }

    // Use transaction with FOR UPDATE for absolute atomicity and race-condition prevention
    $conn->begin_transaction();

    try {
        $stmt = $conn->prepare("SELECT window_start, count FROM rate_limits WHERE user_id = ? AND action_key = ? FOR UPDATE");
        if (!$stmt) {
            $conn->rollback();
            return false;
        }
        $stmt->bind_param("ss", $userId, $actionKey);
        $stmt->execute();
        $res = $stmt->get_result();
        $row = $res->fetch_assoc();
        $stmt->close();

        $now = time();

        if ($row) {
            $startTime = strtotime($row['window_start']);
            $count = (int)$row['count'];

            if (($now - $startTime) < $windowSeconds) {
                if ($count >= $maxPerWindow) {
                    $conn->commit();
                    return false; // Rate limit exceeded
                } else {
                    $upd = $conn->prepare("UPDATE rate_limits SET count = count + 1 WHERE user_id = ? AND action_key = ?");
                    $upd->bind_param("ss", $userId, $actionKey);
                    $upd->execute();
                    $upd->close();
                }
            } else {
                // Window expired, reset window
                $rst = $conn->prepare("UPDATE rate_limits SET window_start = NOW(), count = 1 WHERE user_id = ? AND action_key = ?");
                $rst->bind_param("ss", $userId, $actionKey);
                $rst->execute();
                $rst->close();
            }
            } else {
                $conn->rollback();
                return false; // Reject on duplicate-key race condition
            }
        } else {
            try {
                $ins = $conn->prepare("INSERT INTO rate_limits (user_id, action_key, window_start, count) VALUES (?, ?, NOW(), 1)");
                $ins->bind_param("ss", $userId, $actionKey);
                $ins->execute();
                $ins->close();
            } catch (mysqli_sql_exception $e) {
                if ($e->getCode() == 1062) {
                    $conn->rollback();
                    return false; // Reject: another concurrent request just created this row
                }
                throw $e;
            }
        }

        $conn->commit();
        return true;
    } catch (Throwable $e) {
        $conn->rollback();
        error_log("Rate limit transaction error: " . $e->getMessage());
        return false; // Fail closed on error
    }
}

// Lazy expire stale squads and invites
function lazyExpireSquads($conn, $tenantId) {
    // Expire Forming squads with no activity for > 5 minutes
    $conn->query("UPDATE game_squads SET status = 'Expired' WHERE tenant_id = '$tenantId' AND status = 'Forming' AND created_at < (NOW() - INTERVAL 5 MINUTE)");
    // Expire Invited members with no response for > 2 minutes
    $conn->query("UPDATE game_squad_members SET status = 'Declined' WHERE status = 'Invited' AND invited_at < (NOW() - INTERVAL 2 MINUTE)");
}

$action = $_GET['action'] ?? '';
$tenant_id = $_GET['tenant_id'] ?? ($_POST['tenant_id'] ?? '');

if (empty($tenant_id)) {
    echo json_encode(["status" => "error", "message" => "Missing tenant_id"]);
    exit;
}

lazyExpireSquads($conn, $tenant_id);

try {
    switch ($action) {
        case 'create_squad':
            $data = json_decode(file_get_contents('php://input'));
            $user_id = trim((string)($data->user_id ?? ''));
            $table_id = (int)($data->table_id ?? 0);

            if (empty($user_id)) {
                echo json_encode(["status" => "error", "message" => "Unauthorized user_id"]);
                exit;
            }

            if (!checkRateLimit($conn, $user_id, 'create_squad', 1, 30)) {
                http_response_code(429);
                echo json_encode(["status" => "error", "message" => "Rate limit exceeded. Please wait 30 seconds."]);
                exit;
            }

            $stmt = $conn->prepare("INSERT INTO game_squads (tenant_id, table_id, created_by_user_id, status) VALUES (?, ?, ?, 'Forming')");
            $stmt->bind_param("sis", $tenant_id, $table_id, $user_id);
            if ($stmt->execute()) {
                $squad_id = (int)$stmt->insert_id;
                $stmt->close();

                // Add creator as Joined member
                $m_stmt = $conn->prepare("INSERT INTO game_squad_members (squad_id, user_id, status) VALUES (?, ?, 'Joined')");
                $m_stmt->bind_param("is", $squad_id, $user_id);
                $m_stmt->execute();
                $m_stmt->close();

                echo json_encode(["status" => "success", "squad_id" => $squad_id]);
            } else {
                echo json_encode(["status" => "error", "message" => "Could not create squad"]);
            }
            break;

        case 'invite_to_squad':
            $data = json_decode(file_get_contents('php://input'));
            $user_id = trim((string)($data->user_id ?? ''));
            $squad_id = (int)($data->squad_id ?? 0);
            $invited_user_id = trim((string)($data->invited_user_id ?? ''));

            if (empty($user_id) || $squad_id <= 0 || empty($invited_user_id)) {
                echo json_encode(["status" => "error", "message" => "Invalid parameters"]);
                exit;
            }

            if (!checkRateLimit($conn, $user_id, 'invite_to_squad', 5, 60)) {
                http_response_code(429);
                echo json_encode(["status" => "error", "message" => "Rate limit exceeded. Too many invites."]);
                exit;
            }

            // Verify squad exists and caller is creator
            $s_stmt = $conn->prepare("SELECT created_by_user_id, status FROM game_squads WHERE id = ? AND tenant_id = ? LIMIT 1");
            $s_stmt->bind_param("is", $squad_id, $tenant_id);
            $s_stmt->execute();
            $s_res = $s_stmt->get_result();
            if ($s_row = $s_res->fetch_assoc()) {
                if ($s_row['created_by_user_id'] !== $user_id) {
                    echo json_encode(["status" => "error", "message" => "Only squad host can invite members"]);
                    exit;
                }
                if ($s_row['status'] !== 'Forming') {
                    echo json_encode(["status" => "error", "message" => "Squad is already in progress or closed"]);
                    exit;
                }
            } else {
                echo json_encode(["status" => "error", "message" => "Squad not found"]);
                exit;
            }
            $s_stmt->close();

            // Server-side verification: check if invited_user_id is in restaurant_presence for this tenant within last 5 minutes
            $p_stmt = $conn->prepare("SELECT user_id FROM restaurant_presence WHERE tenant_id = ? AND user_id = ? AND last_seen > (NOW() - INTERVAL 5 MINUTE) LIMIT 1");
            $p_stmt->bind_param("ss", $tenant_id, $invited_user_id);
            $p_stmt->execute();
            if ($p_stmt->get_result()->num_rows === 0) {
                echo json_encode(["status" => "error", "message" => "Invited user is not currently active in the venue"]);
                exit;
            }
            $p_stmt->close();

            // Insert invite
            $i_stmt = $conn->prepare("INSERT INTO game_squad_members (squad_id, user_id, status) VALUES (?, ?, 'Invited') ON DUPLICATE KEY UPDATE status = IF(status = 'Declined' OR status = 'Left', 'Invited', status)");
            $i_stmt->bind_param("is", $squad_id, $invited_user_id);
            if ($i_stmt->execute()) {
                // Insert notification for invited user
                $n_title = "Squad Invite! 🎮";
                $n_msg = "You've been invited to a Tap War squad battle. Tap to join!";
                $n_ins = $conn->prepare("INSERT INTO notifications (tenant_id, user_id, title, message, type, sender_id) VALUES (?, ?, ?, ?, 'squad_invite', ?)");
                if ($n_ins) {
                    $n_ins->bind_param("sssss", $tenant_id, $invited_user_id, $n_title, $n_msg, $user_id);
                    $n_ins->execute();
                    $n_ins->close();
                }

                echo json_encode(["status" => "success", "message" => "Invite sent"]);
            } else {
                echo json_encode(["status" => "error", "message" => "Could not send invite"]);
            }
            $i_stmt->close();
            break;

        case 'respond_to_invite':
            $data = json_decode(file_get_contents('php://input'));
            $user_id = trim((string)($data->user_id ?? ''));
            $squad_id = (int)($data->squad_id ?? 0);
            $accept = (bool)($data->accept ?? false);

            if (empty($user_id) || $squad_id <= 0) {
                echo json_encode(["status" => "error", "message" => "Invalid parameters"]);
                exit;
            }

            $new_status = $accept ? 'Joined' : 'Declined';
            $stmt = $conn->prepare("UPDATE game_squad_members SET status = ?, responded_at = NOW() WHERE squad_id = ? AND user_id = ?");
            $stmt->bind_param("sis", $new_status, $squad_id, $user_id);
            if ($stmt->execute()) {
                echo json_encode(["status" => "success", "response" => $new_status]);
            } else {
                echo json_encode(["status" => "error", "message" => "Failed to update response"]);
            }
            $stmt->close();
            break;

        case 'get_squad_status':
            $squad_id = (int)($_GET['squad_id'] ?? 0);
            $user_id = trim((string)($_GET['user_id'] ?? ''));

            if ($squad_id <= 0) {
                echo json_encode(["status" => "error", "message" => "Invalid squad_id"]);
                exit;
            }

            $stmt = $conn->prepare("SELECT * FROM game_squads WHERE id = ? AND tenant_id = ? LIMIT 1");
            $stmt->bind_param("is", $squad_id, $tenant_id);
            $stmt->execute();
            $squad = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            if (!$squad) {
                echo json_encode(["status" => "error", "message" => "Squad not found"]);
                exit;
            }

            // Check if user's order became Ready mid-match or active order status changed; if so, mark as Left
            $ord_stmt = $conn->prepare("SELECT status FROM orders WHERE tenant_id = ? AND user_id = ? ORDER BY id DESC LIMIT 1");
            $ord_stmt->bind_param("ss", $tenant_id, $user_id);
            $ord_stmt->execute();
            $ord_res = $ord_stmt->get_result();
            if ($ord_row = $ord_res->fetch_assoc()) {
                if (strtolower($ord_row['status']) === 'ready' && $squad['status'] === 'InProgress') {
                    // Mark user as Left early
                    $l_stmt = $conn->prepare("UPDATE game_squad_members SET status = 'Left' WHERE squad_id = ? AND user_id = ?");
                    $l_stmt->bind_param("is", $squad_id, $user_id);
                    $l_stmt->execute();
                    $l_stmt->close();
                }
            }
            $ord_stmt->close();

            // Fetch members
            $m_stmt = $conn->prepare("SELECT m.user_id, m.status, COALESCE(c.name, p.user_name, 'Diner') as user_name
                                      FROM game_squad_members m
                                      LEFT JOIN customers c ON LOWER(c.email) = LOWER(m.user_id) AND c.tenant_id = ?
                                      LEFT JOIN restaurant_presence p ON p.user_id = m.user_id AND p.tenant_id = ?
                                      WHERE m.squad_id = ?");
            $m_stmt->bind_param("ssi", $tenant_id, $tenant_id, $squad_id);
            $m_stmt->execute();
            $members_res = $m_stmt->get_result();
            $members = [];
            while ($row = $members_res->fetch_assoc()) {
                $members[] = $row;
            }
            $m_stmt->close();

            echo json_encode([
                "status" => "success",
                "squad" => $squad,
                "members" => $members
            ]);
            break;

        case 'start_squad_game':
            $data = json_decode(file_get_contents('php://input'));
            $user_id = trim((string)($data->user_id ?? ''));
            $squad_id = (int)($data->squad_id ?? 0);

            if (empty($user_id) || $squad_id <= 0) {
                echo json_encode(["status" => "error", "message" => "Invalid parameters"]);
                exit;
            }

            // Verify caller is squad CREATOR/host
            $s_stmt = $conn->prepare("SELECT created_by_user_id, status FROM game_squads WHERE id = ? AND tenant_id = ? LIMIT 1");
            $s_stmt->bind_param("is", $squad_id, $tenant_id);
            $s_stmt->execute();
            $s_res = $s_stmt->get_result();
            if ($s_row = $s_res->fetch_assoc()) {
                if ($s_row['created_by_user_id'] !== $user_id) {
                    echo json_encode(["status" => "error", "message" => "Only the squad creator can start the game"]);
                    exit;
                }
            } else {
                echo json_encode(["status" => "error", "message" => "Squad not found"]);
                exit;
            }
            $s_stmt->close();

            // Verify at least 2 Joined members
            $cnt_stmt = $conn->prepare("SELECT COUNT(*) as cnt FROM game_squad_members WHERE squad_id = ? AND status = 'Joined'");
            $cnt_stmt->bind_param("i", $squad_id);
            $cnt_stmt->execute();
            $cnt_row = $cnt_stmt->get_result()->fetch_assoc();
            $cnt_stmt->close();

            if ((int)$cnt_row['cnt'] < 2) {
                echo json_encode(["status" => "error", "message" => "At least 2 joined members are required to start"]);
                exit;
            }

            // Set status to Ready / InProgress and start_at = NOW() + 5 seconds
            $upd = $conn->prepare("UPDATE game_squads SET status = 'InProgress', started_at = NOW(), start_at = DATE_ADD(NOW(), INTERVAL 5 SECOND) WHERE id = ?");
            $upd->bind_param("i", $squad_id);
            if ($upd->execute()) {
                echo json_encode(["status" => "success", "message" => "Game starting"]);
            } else {
                echo json_encode(["status" => "error", "message" => "Could not start game"]);
            }
            $upd->close();
            break;

        case 'submit_tap_batch':
            $data = json_decode(file_get_contents('php://input'));
            $user_id = trim((string)($data->user_id ?? ''));
            $squad_id = (int)($data->squad_id ?? 0);
            $tap_increment = (int)($data->tap_count_increment ?? 0);

            if (empty($user_id) || $squad_id <= 0 || $tap_increment <= 0) {
                echo json_encode(["status" => "error", "message" => "Invalid tap batch data"]);
                exit;
            }

            // Rate limit: max once per 800ms per user per squad
            if (!checkRateLimit($conn, $user_id, 'tap_batch_' . $squad_id, 1, 1)) {
                http_response_code(429);
                echo json_encode(["status" => "error", "message" => "Tap batch submitted too frequently"]);
                exit;
            }

            // Atomic increment
            $stmt = $conn->prepare("INSERT INTO game_squad_scores (squad_id, user_id, tap_count) VALUES (?, ?, ?)
                                    ON DUPLICATE KEY UPDATE tap_count = tap_count + ?");
            $stmt->bind_param("isii", $squad_id, $user_id, $tap_increment, $tap_increment);
            if ($stmt->execute()) {
                echo json_encode(["status" => "success"]);
            } else {
                echo json_encode(["status" => "error", "message" => "Failed to record taps"]);
            }
            $stmt->close();
            break;

        case 'get_active_squad':
            $user_id = trim((string)($_GET['user_id'] ?? ''));
            if (empty($user_id)) {
                echo json_encode(["status" => "error", "message" => "Missing user_id"]);
                exit;
            }
            $stmt = $conn->prepare("SELECT s.*, m.status as member_status FROM game_squad_members m JOIN game_squads s ON s.id = m.squad_id WHERE m.user_id = ? AND s.tenant_id = ? AND s.status IN ('Forming', 'Ready', 'InProgress') ORDER BY s.id DESC LIMIT 1");
            $stmt->bind_param("ss", $user_id, $tenant_id);
            $stmt->execute();
            $res = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            if ($res) {
                // If member status was Invited, auto-update to Joined when opening lobby
                if ($res['member_status'] === 'Invited') {
                    $u_stmt = $conn->prepare("UPDATE game_squad_members SET status = 'Joined', responded_at = NOW() WHERE squad_id = ? AND user_id = ?");
                    $u_stmt->bind_param("is", $res['id'], $user_id);
                    $u_stmt->execute();
                    $u_stmt->close();
                    $res['member_status'] = 'Joined';
                }
                echo json_encode(["status" => "success", "squad" => $res]);
            } else {
                echo json_encode(["status" => "error", "message" => "No active squad found"]);
            }
            break;

        case 'get_game_state':
            $squad_id = (int)($_GET['squad_id'] ?? 0);
            if ($squad_id <= 0) {
                echo json_encode(["status" => "error", "message" => "Invalid squad_id"]);
                exit;
            }

            $s_stmt = $conn->prepare("SELECT status, start_at, started_at FROM game_squads WHERE id = ? AND tenant_id = ? LIMIT 1");
            $s_stmt->bind_param("is", $squad_id, $tenant_id);
            $s_stmt->execute();
            $squad = $s_stmt->get_result()->fetch_assoc();
            $s_stmt->close();

            if (!$squad) {
                echo json_encode(["status" => "error", "message" => "Squad not found"]);
                exit;
            }

            // Fetch scores and members
            $sc_stmt = $conn->prepare("SELECT s.user_id, s.tap_count, m.status, COALESCE(c.name, p.user_name, 'Diner') as user_name
                                       FROM game_squad_scores s
                                       JOIN game_squad_members m ON m.squad_id = s.squad_id AND m.user_id = s.user_id
                                       LEFT JOIN customers c ON LOWER(c.email) = LOWER(s.user_id) AND c.tenant_id = ?
                                       LEFT JOIN restaurant_presence p ON p.user_id = s.user_id AND p.tenant_id = ?
                                       WHERE s.squad_id = ?
                                       ORDER BY s.tap_count DESC");
            $sc_stmt->bind_param("ssi", $tenant_id, $tenant_id, $squad_id);
            $sc_stmt->execute();
            $scores_res = $sc_stmt->get_result();
            $scores = [];
            while ($row = $scores_res->fetch_assoc()) {
                $scores[] = $row;
            }
            $sc_stmt->close();

            echo json_encode([
                "status" => "success",
                "squad_status" => $squad['status'],
                "start_at" => $squad['start_at'],
                "scores" => $scores
            ]);
            break;

        default:
            echo json_encode(["status" => "error", "message" => "Invalid action"]);
            break;
    }
} catch (Throwable $e) {
    error_log('Game Squad API action "' . $action . '" failed: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Request failed"]);
}

$conn->close();
?>
