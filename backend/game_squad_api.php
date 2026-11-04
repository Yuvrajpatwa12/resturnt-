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
require_once 'email_notification_common.php';

const MAX_HUMAN_TAPS_PER_SECOND = 12;
const MAX_BATTLEGROUND_PLAYERS = 10;
const BATTLEGROUND_DNF_GRACE_SECONDS = 10;

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
    session_id INT DEFAULT NULL,
    created_by_user_id VARCHAR(100) NOT NULL,
    game_type VARCHAR(50) NOT NULL DEFAULT 'tap_war',
    status VARCHAR(50) NOT NULL DEFAULT 'Forming', -- Forming, Ready, InProgress, Completed, Cancelled, Expired
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at DATETIME DEFAULT NULL,
    start_at DATETIME DEFAULT NULL,
    max_players INT NOT NULL DEFAULT " . MAX_BATTLEGROUND_PLAYERS . ",
    duration_seconds INT NOT NULL DEFAULT 30,
    result_json LONGTEXT DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

$conn->query("CREATE TABLE IF NOT EXISTS game_squad_members (
    id INT AUTO_INCREMENT PRIMARY KEY,
    squad_id INT NOT NULL,
    user_id VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Invited', -- Invited, Joined, Declined, Left
    member_source VARCHAR(20) NOT NULL DEFAULT 'invite',
    invited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    responded_at DATETIME DEFAULT NULL,
    last_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_squad_user (squad_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

$conn->query("CREATE TABLE IF NOT EXISTS game_squad_scores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    squad_id INT NOT NULL,
    user_id VARCHAR(100) NOT NULL,
    tap_count BIGINT NOT NULL DEFAULT 0,
    disqualified TINYINT(1) NOT NULL DEFAULT 0,
    reached_at_timestamp DATETIME(6) DEFAULT NULL,
    is_dnf TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_score_squad_user (squad_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");

function ensureGameSquadColumn($conn, $table, $column, $definition) {
    $result = $conn->query("SHOW COLUMNS FROM `$table` LIKE '$column'");
    if ($result && $result->num_rows === 0) {
        $conn->query("ALTER TABLE `$table` ADD COLUMN `$column` $definition");
    }
}

ensureGameSquadColumn($conn, 'game_squads', 'session_id', 'INT DEFAULT NULL');
ensureGameSquadColumn($conn, 'game_squads', 'duration_seconds', 'INT NOT NULL DEFAULT 30');
ensureGameSquadColumn($conn, 'game_squads', 'result_json', 'LONGTEXT DEFAULT NULL');
ensureGameSquadColumn($conn, 'game_squad_members', 'member_source', "VARCHAR(20) NOT NULL DEFAULT 'invite'");
ensureGameSquadColumn($conn, 'game_squad_scores', 'disqualified', 'TINYINT(1) NOT NULL DEFAULT 0');
ensureGameSquadColumn($conn, 'game_squad_scores', 'reached_at_timestamp', 'DATETIME(6) DEFAULT NULL');
ensureGameSquadColumn($conn, 'game_squad_scores', 'is_dnf', 'TINYINT(1) NOT NULL DEFAULT 0');
ensureGameSquadColumn($conn, 'notifications', 'related_squad_id', 'INT DEFAULT NULL');
$conn->query("ALTER TABLE rate_limits MODIFY user_id VARCHAR(190) NOT NULL");
$conn->query("ALTER TABLE game_squads MODIFY created_by_user_id VARCHAR(190) NOT NULL");
$conn->query("ALTER TABLE game_squad_members MODIFY user_id VARCHAR(190) NOT NULL");
$conn->query("ALTER TABLE game_squad_scores MODIFY user_id VARCHAR(190) NOT NULL");
$conn->query("ALTER TABLE game_squad_scores MODIFY tap_count BIGINT NOT NULL DEFAULT 0");
$conn->query("ALTER TABLE game_squads MODIFY max_players INT NOT NULL DEFAULT " . MAX_BATTLEGROUND_PLAYERS);

function resolveBattlegroundIfReady($conn, $tenantId, $squadId) {
    $conn->begin_transaction();
    try {
        $squadStmt = $conn->prepare("SELECT status, game_type, start_at, duration_seconds, result_json
            FROM game_squads WHERE id = ? AND tenant_id = ? FOR UPDATE");
        $squadStmt->bind_param("is", $squadId, $tenantId);
        $squadStmt->execute();
        $squad = $squadStmt->get_result()->fetch_assoc();
        $squadStmt->close();
        if (!$squad || $squad['game_type'] !== 'battleground') {
            $conn->commit();
            return null;
        }
        if ($squad['status'] === 'Completed') {
            $conn->commit();
            return json_decode($squad['result_json'] ?? 'null', true);
        }
        if ($squad['status'] !== 'InProgress') {
            $conn->commit();
            return null;
        }

        $counts = $conn->prepare("SELECT COUNT(*) AS total,
                SUM(CASE WHEN sc.id IS NOT NULL THEN 1 ELSE 0 END) AS submitted,
                NOW() >= TIMESTAMPADD(SECOND, ? + ?, ?) AS past_deadline
            FROM game_squad_members m
            LEFT JOIN game_squad_scores sc ON sc.squad_id = m.squad_id AND sc.user_id = m.user_id
            WHERE m.squad_id = ? AND m.status = 'Joined'");
        $graceSeconds = BATTLEGROUND_DNF_GRACE_SECONDS;
        $duration = (int)$squad['duration_seconds'];
        $startAt = $squad['start_at'];
        $counts->bind_param("iisi", $duration, $graceSeconds, $startAt, $squadId);
        $counts->execute();
        $countRow = $counts->get_result()->fetch_assoc();
        $counts->close();
        $total = (int)($countRow['total'] ?? 0);
        $submitted = (int)($countRow['submitted'] ?? 0);
        $pastDeadline = (int)($countRow['past_deadline'] ?? 0) === 1;
        if ($total === 0 || ($submitted < $total && !$pastDeadline)) {
            $conn->commit();
            return null;
        }

        if ($pastDeadline && $submitted < $total) {
            $dnfStmt = $conn->prepare("INSERT IGNORE INTO game_squad_scores
                (squad_id, user_id, tap_count, disqualified, reached_at_timestamp, is_dnf)
                SELECT ?, m.user_id, 0, 0, NULL, 1
                FROM game_squad_members m
                LEFT JOIN game_squad_scores sc ON sc.squad_id = m.squad_id AND sc.user_id = m.user_id
                WHERE m.squad_id = ? AND m.status = 'Joined' AND sc.id IS NULL");
            $dnfStmt->bind_param("ii", $squadId, $squadId);
            $dnfStmt->execute();
            $dnfStmt->close();
        }

        $scoresStmt = $conn->prepare("SELECT sc.user_id, sc.tap_count, sc.disqualified,
                sc.reached_at_timestamp, sc.is_dnf,
                COALESCE(c.name, p.user_name, 'Diner') AS user_name
            FROM game_squad_scores sc
            JOIN game_squad_members m ON m.squad_id = sc.squad_id AND m.user_id = sc.user_id
            LEFT JOIN customers c
                ON LOWER(c.email) COLLATE utf8mb4_general_ci =
                   LOWER(sc.user_id) COLLATE utf8mb4_general_ci
                AND c.tenant_id COLLATE utf8mb4_general_ci =
                    ? COLLATE utf8mb4_general_ci
            LEFT JOIN restaurant_presence p
                ON p.user_id COLLATE utf8mb4_general_ci =
                   sc.user_id COLLATE utf8mb4_general_ci
                AND p.tenant_id COLLATE utf8mb4_general_ci =
                    ? COLLATE utf8mb4_general_ci
            WHERE sc.squad_id = ? AND m.status = 'Joined'
            ORDER BY sc.tap_count DESC");
        $scoresStmt->bind_param("ssi", $tenantId, $tenantId, $squadId);
        $scoresStmt->execute();
        $scoresResult = $scoresStmt->get_result();
        $scores = [];
        $highest = -1;
        while ($score = $scoresResult->fetch_assoc()) {
            $score['tap_count'] = (int)$score['tap_count'];
            $score['disqualified'] = (int)$score['disqualified'];
            $score['is_dnf'] = (int)$score['is_dnf'];
            $scores[] = $score;
            if ($score['disqualified'] === 0 && $score['is_dnf'] === 0) {
                $highest = max($highest, $score['tap_count']);
            }
        }
        $scoresStmt->close();

        $leaders = array_values(array_filter($scores, function($score) use ($highest) {
            return $highest >= 0 && $score['disqualified'] === 0 &&
                $score['is_dnf'] === 0 && $score['tap_count'] === $highest;
        }));
        $result = [
            'result_type' => 'no_winner',
            'winner_user_id' => null,
            'draw_user_ids' => [],
            'scores' => $scores
        ];
        if (count($leaders) === 1) {
            $result['result_type'] = 'winner';
            $result['winner_user_id'] = $leaders[0]['user_id'];
        } elseif (count($leaders) > 1) {
            $missingTimestamp = false;
            $earliest = null;
            foreach ($leaders as $leader) {
                if (empty($leader['reached_at_timestamp'])) {
                    $missingTimestamp = true;
                    break;
                }
                try {
                    $timestamp = (new DateTimeImmutable($leader['reached_at_timestamp'], new DateTimeZone('UTC')))
                        ->setTimezone(new DateTimeZone('UTC'))
                        ->format('Y-m-d H:i:s.u');
                } catch (Throwable $e) {
                    $missingTimestamp = true;
                    break;
                }
                $leader['_reached_key'] = $timestamp;
                $earliest = $earliest === null || strcmp($timestamp, $earliest) < 0
                    ? $timestamp
                    : $earliest;
            }
            if ($missingTimestamp) {
                $result['result_type'] = 'draw';
                $result['draw_user_ids'] = array_column($leaders, 'user_id');
            } else {
                $fastest = array_values(array_filter($leaders, function($leader) use ($earliest) {
                    return $leader['_reached_key'] === $earliest;
                }));
                if (count($fastest) === 1) {
                    $result['result_type'] = 'winner';
                    $result['winner_user_id'] = $fastest[0]['user_id'];
                } else {
                    $result['result_type'] = 'draw';
                    $result['draw_user_ids'] = array_column($fastest, 'user_id');
                }
            }
        }

        $resultJson = json_encode($result);
        $completeStmt = $conn->prepare("UPDATE game_squads SET status = 'Completed', result_json = ?
            WHERE id = ? AND status = 'InProgress'");
        $completeStmt->bind_param("si", $resultJson, $squadId);
        $completeStmt->execute();
        $completeStmt->close();
        $conn->commit();
        return $result;
    } catch (Throwable $e) {
        $conn->rollback();
        throw $e;
    }
}

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

        case 'create_battleground':
            $data = json_decode(file_get_contents('php://input'));
            $user_id = trim((string)(authenticatedCustomerEmail($conn, $tenant_id) ?? ''));
            $duration_seconds = (int)($data->duration_seconds ?? 0);

            if ($user_id === '') {
                http_response_code(401);
                echo json_encode(["status" => "error", "message" => "Sign in to create a Battleground"]);
                exit;
            }
            if (!in_array($duration_seconds, [60, 180, 300], true)) {
                echo json_encode(["status" => "error", "message" => "Choose a 1, 3, or 5 minute duration"]);
                exit;
            }
            if (!checkRateLimit($conn, $user_id, 'create_battleground', 1, 30)) {
                http_response_code(429);
                echo json_encode(["status" => "error", "message" => "Rate limit exceeded. Please wait 30 seconds."]);
                exit;
            }

            $orderStmt = $conn->prepare("SELECT o.table_id, o.session_id, t.table_number
                FROM orders o
                LEFT JOIN restaurant_tables t ON t.id = o.table_id AND t.tenant_id = o.tenant_id
                WHERE o.tenant_id = ?
                    AND (LOWER(o.user_id) = LOWER(?) OR LOWER(o.customer_email) = LOWER(?))
                    AND o.table_id IS NOT NULL AND o.table_id > 0
                ORDER BY o.id DESC LIMIT 1");
            $orderStmt->bind_param("sss", $tenant_id, $user_id, $user_id);
            $orderStmt->execute();
            $orderRow = $orderStmt->get_result()->fetch_assoc();
            $orderStmt->close();
            if (!$orderRow) {
                echo json_encode(["status" => "error", "message" => "A table order is required to create a Battleground"]);
                exit;
            }
            $table_id = (int)$orderRow['table_id'];
            $session_id = (int)($orderRow['session_id'] ?? 0);
            $table_number = (int)($orderRow['table_number'] ?? 0);

            $conn->begin_transaction();
            try {
                $squadStmt = $conn->prepare("INSERT INTO game_squads
                    (tenant_id, table_id, session_id, created_by_user_id, game_type, status, max_players, duration_seconds)
                    VALUES (?, ?, NULLIF(?, 0), ?, 'battleground', 'Forming', ?, ?)");
                $maxPlayers = MAX_BATTLEGROUND_PLAYERS;
                $squadStmt->bind_param("siisii", $tenant_id, $table_id, $session_id, $user_id, $maxPlayers, $duration_seconds);
                $squadStmt->execute();
                $squad_id = (int)$conn->insert_id;
                $squadStmt->close();

                $creatorStmt = $conn->prepare("INSERT INTO game_squad_members
                    (squad_id, user_id, status, member_source) VALUES (?, ?, 'Joined', 'creator')");
                $creatorStmt->bind_param("is", $squad_id, $user_id);
                $creatorStmt->execute();
                $creatorStmt->close();
                $memberIds = [];

                if ($table_number > 0) {
                    $tableMembersStmt = $conn->prepare("SELECT DISTINCT user_id
                        FROM restaurant_presence
                        WHERE tenant_id = ? AND table_number = ?
                            AND user_id <> ? AND last_seen > (NOW() - INTERVAL 5 MINUTE)");
                    $tableMembersStmt->bind_param("sis", $tenant_id, $table_number, $user_id);
                    $tableMembersStmt->execute();
                    $tableMembers = $tableMembersStmt->get_result();
                    while ($row = $tableMembers->fetch_assoc()) {
                        $memberIds[] = trim((string)$row['user_id']);
                    }
                    $tableMembersStmt->close();
                }
                if ($session_id > 0) {
                    $sessionMembersStmt = $conn->prepare("SELECT DISTINCT
                            CASE WHEN customer_email IS NOT NULL AND customer_email <> ''
                                THEN customer_email ELSE user_id END AS user_id
                        FROM orders
                        WHERE tenant_id = ? AND session_id = ? AND LOWER(user_id) <> LOWER(?)
                            AND LOWER(status) IN ('pending', 'cooking', 'preparing')");
                    $sessionMembersStmt->bind_param("sis", $tenant_id, $session_id, $user_id);
                    $sessionMembersStmt->execute();
                    $sessionMembers = $sessionMembersStmt->get_result();
                    while ($row = $sessionMembers->fetch_assoc()) {
                        $memberIds[] = trim((string)$row['user_id']);
                    }
                    $sessionMembersStmt->close();
                }
                $memberIds = array_values(array_unique(array_filter($memberIds)));
                $autoAdded = 0;
                $addedMemberIds = [];
                foreach ($memberIds as $memberId) {
                    if ($autoAdded >= MAX_BATTLEGROUND_PLAYERS - 1) break;
                    $memberStmt = $conn->prepare("INSERT IGNORE INTO game_squad_members
                        (squad_id, user_id, status, member_source) VALUES (?, ?, 'Joined', 'table')");
                    $memberStmt->bind_param("is", $squad_id, $memberId);
                    $memberStmt->execute();
                    if ($memberStmt->affected_rows === 1) {
                        $autoAdded++;
                        $addedMemberIds[] = $memberId;
                    }
                    $memberStmt->close();
                }
                foreach ($addedMemberIds as $memberId) {
                    $notificationStmt = $conn->prepare("INSERT INTO notifications
                        (tenant_id, user_id, title, message, type, sender_id, related_squad_id)
                        VALUES (?, ?, 'Battleground at your table', 'You have been added to your table Battleground. Open the lobby when you are ready!', 'squad_table_added', ?, ?)");
                    if ($notificationStmt) {
                        $notificationStmt->bind_param("sssi", $tenant_id, $memberId, $user_id, $squad_id);
                        $notificationStmt->execute();
                        $notificationStmt->close();
                    }
                }
                $conn->commit();
                echo json_encode([
                    "status" => "success",
                    "squad_id" => $squad_id,
                    "table_members_added" => $autoAdded,
                    "duration_seconds" => $duration_seconds
                ]);
            } catch (Throwable $e) {
                $conn->rollback();
                throw $e;
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
            if ($user_id === $invited_user_id) {
                echo json_encode(["status" => "error", "message" => "You are already in your own squad"]);
                exit;
            }

            $typeStmt = $conn->prepare("SELECT game_type FROM game_squads
                WHERE id = ? AND tenant_id = ? LIMIT 1");
            $typeStmt->bind_param("is", $squad_id, $tenant_id);
            $typeStmt->execute();
            $squadType = $typeStmt->get_result()->fetch_assoc();
            $typeStmt->close();
            if ($squadType && $squadType['game_type'] === 'battleground') {
                $authenticatedUserId = trim(
                    (string)(authenticatedCustomerEmail($conn, $tenant_id) ?? '')
                );
                if ($authenticatedUserId === '') {
                    http_response_code(401);
                    echo json_encode([
                        "status" => "error",
                        "message" => "Sign in again before inviting someone to this Battleground"
                    ]);
                    exit;
                }
                $user_id = $authenticatedUserId;
            }

            if (!checkRateLimit($conn, $user_id, 'invite_to_squad', 5, 60)) {
                http_response_code(429);
                echo json_encode(["status" => "error", "message" => "Rate limit exceeded. Too many invites."]);
                exit;
            }

            // Verify squad exists and caller is creator
            $s_stmt = $conn->prepare("SELECT created_by_user_id, status, max_players, game_type FROM game_squads WHERE id = ? AND tenant_id = ? LIMIT 1 FOR UPDATE");
            $conn->begin_transaction();
            $s_stmt->bind_param("is", $squad_id, $tenant_id);
            $s_stmt->execute();
            $s_res = $s_stmt->get_result();
            if ($s_row = $s_res->fetch_assoc()) {
                if (strcasecmp($s_row['created_by_user_id'], $user_id) !== 0) {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "Only squad host can invite members"]);
                    exit;
                }
                if ($s_row['status'] !== 'Forming') {
                    $conn->rollback();
                    http_response_code(409);
                    echo json_encode(["status" => "error", "message" => "Squad is already in progress or closed"]);
                    exit;
                }
            } else {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "Squad not found"]);
                exit;
            }
            $s_stmt->close();
            $existingStmt = $conn->prepare("SELECT status FROM game_squad_members WHERE squad_id = ? AND user_id = ? LIMIT 1");
            $existingStmt->bind_param("is", $squad_id, $invited_user_id);
            $existingStmt->execute();
            $existingMember = $existingStmt->get_result()->fetch_assoc();
            $existingStmt->close();
            if ($existingMember && $existingMember['status'] === 'Joined') {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "This diner is already a member"]);
                exit;
            }
            if ($existingMember && $existingMember['status'] === 'Invited') {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "This diner already has a pending invite"]);
                exit;
            }
            if ($existingMember && $existingMember['status'] === 'JoinRequested') {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "This diner has already requested to join"]);
                exit;
            }
            if (!$existingMember || !in_array($existingMember['status'], ['Joined', 'Invited'], true)) {
                $countStmt = $conn->prepare("SELECT COUNT(*) AS cnt FROM game_squad_members
                    WHERE squad_id = ? AND status IN ('Joined', 'Invited', 'JoinRequested')");
                $countStmt->bind_param("i", $squad_id);
                $countStmt->execute();
                $count = (int)$countStmt->get_result()->fetch_assoc()['cnt'];
                $countStmt->close();
                if ($count >= (int)$s_row['max_players']) {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "Battleground is full"]);
                    exit;
                }
            }

            // Server-side verification: check if invited_user_id is in restaurant_presence for this tenant within last 5 minutes
            $p_stmt = $conn->prepare("SELECT user_id FROM restaurant_presence WHERE tenant_id = ? AND user_id = ? AND last_seen > (NOW() - INTERVAL 5 MINUTE) LIMIT 1");
            $p_stmt->bind_param("ss", $tenant_id, $invited_user_id);
            $p_stmt->execute();
            if ($p_stmt->get_result()->num_rows === 0) {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "Invited user is not currently active in the venue"]);
                exit;
            }
            $p_stmt->close();

            // Insert invite
            $i_stmt = $conn->prepare("INSERT INTO game_squad_members (squad_id, user_id, status) VALUES (?, ?, 'Invited') ON DUPLICATE KEY UPDATE status = IF(status = 'Declined' OR status = 'Left', 'Invited', status)");
            $i_stmt->bind_param("is", $squad_id, $invited_user_id);
            if ($i_stmt->execute()) {
                // Insert notification for invited user
                $n_title = $s_row['game_type'] === 'battleground'
                    ? "Battleground Invite! 🎮"
                    : "Squad Invite! 🎮";
                $n_msg = $s_row['game_type'] === 'battleground'
                    ? "You've been invited to a Battleground. Tap to join!"
                    : "You've been invited to a Tap War squad battle. Tap to join!";
                $n_ins = $conn->prepare("INSERT INTO notifications
                    (tenant_id, user_id, title, message, type, sender_id, related_squad_id)
                    VALUES (?, ?, ?, ?, 'squad_invite', ?, ?)");
                if ($n_ins) {
                    $n_ins->bind_param("sssssi", $tenant_id, $invited_user_id, $n_title, $n_msg, $user_id, $squad_id);
                    $n_ins->execute();
                    $n_ins->close();
                }

                $conn->commit();
                echo json_encode(["status" => "success", "message" => "Invite sent"]);
            } else {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "Could not send invite"]);
            }
            $i_stmt->close();
            break;

        case 'respond_to_invite':
            $data = json_decode(file_get_contents('php://input'));
            $user_id = trim((string)($data->user_id ?? ''));
            $squad_id = (int)($data->squad_id ?? 0);
            $accept = (bool)($data->accept ?? false);

            if ($squad_id <= 0) {
                echo json_encode(["status" => "error", "message" => "Invalid parameters"]);
                exit;
            }

            $conn->begin_transaction();
            $squadStmt = $conn->prepare("SELECT status, max_players, game_type FROM game_squads
                WHERE id = ? AND tenant_id = ? FOR UPDATE");
            $squadStmt->bind_param("is", $squad_id, $tenant_id);
            $squadStmt->execute();
            $squadRow = $squadStmt->get_result()->fetch_assoc();
            $squadStmt->close();
            if (!$squadRow) {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "Squad not found"]);
                exit;
            }
            if ($squadRow['game_type'] === 'battleground') {
                $authenticatedUserId = trim(
                    (string)(authenticatedCustomerEmail($conn, $tenant_id) ?? '')
                );
                if ($authenticatedUserId === '') {
                    $conn->rollback();
                    http_response_code(401);
                    echo json_encode(["status" => "error", "message" => "Sign in to respond to this Battleground invite"]);
                    exit;
                }
                $user_id = $authenticatedUserId;
            } elseif ($user_id === '') {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "Invalid parameters"]);
                exit;
            }
            if ($accept && $squadRow['status'] !== 'Forming') {
                $conn->rollback();
                http_response_code(409);
                echo json_encode(["status" => "error", "message" => "This Battleground has already started; new members cannot join"]);
                exit;
            }
            $memberStmt = $conn->prepare("SELECT status FROM game_squad_members
                WHERE squad_id = ? AND user_id = ? FOR UPDATE");
            $memberStmt->bind_param("is", $squad_id, $user_id);
            $memberStmt->execute();
            $memberRow = $memberStmt->get_result()->fetch_assoc();
            $memberStmt->close();
            if (!$memberRow || $memberRow['status'] !== 'Invited') {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "No pending invite was found"]);
                exit;
            }
            if ($accept) {
                $countStmt = $conn->prepare("SELECT COUNT(*) AS cnt FROM game_squad_members
                    WHERE squad_id = ? AND status IN ('Joined', 'Invited', 'JoinRequested')");
                $countStmt->bind_param("i", $squad_id);
                $countStmt->execute();
                $count = (int)$countStmt->get_result()->fetch_assoc()['cnt'];
                $countStmt->close();
                if ($count > (int)$squadRow['max_players']) {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "Battleground is full"]);
                    exit;
                }
            }
            $new_status = $accept ? 'Joined' : 'Declined';
            $updateStmt = $conn->prepare("UPDATE game_squad_members SET status = ?, responded_at = NOW()
                WHERE squad_id = ? AND user_id = ? AND status = 'Invited'");
            $updateStmt->bind_param("sis", $new_status, $squad_id, $user_id);
            if ($updateStmt->execute()) {
                $conn->commit();
                echo json_encode(["status" => "success", "response" => $new_status]);
            } else {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "Failed to update response"]);
            }
            $updateStmt->close();
            break;

        case 'get_open_battlegrounds':
            $user_id = trim((string)(authenticatedCustomerEmail($conn, $tenant_id) ?? ''));
            if ($user_id === '') {
                http_response_code(401);
                echo json_encode(["status" => "error", "message" => "Sign in to browse Battlegrounds"]);
                exit;
            }
            $openStmt = $conn->prepare("SELECT s.id AS squad_id, s.table_id, s.duration_seconds,
                    s.max_players, s.created_at,
                    COALESCE(c.name, p.user_name, 'Diner') AS host_name,
                    CASE WHEN LOWER(s.created_by_user_id) COLLATE utf8mb4_general_ci =
                        LOWER(?) COLLATE utf8mb4_general_ci THEN 1 ELSE 0 END AS is_host,
                    COUNT(DISTINCT CASE
                        WHEN m.status IN ('Joined', 'Invited', 'JoinRequested')
                        THEN m.user_id END) AS joined_count,
                    MAX(CASE WHEN m.user_id COLLATE utf8mb4_general_ci =
                        ? COLLATE utf8mb4_general_ci THEN m.status ELSE NULL END) AS member_status
                FROM game_squads s
                LEFT JOIN game_squad_members m ON m.squad_id = s.id
                LEFT JOIN customers c
                    ON LOWER(c.email) COLLATE utf8mb4_general_ci =
                       LOWER(s.created_by_user_id) COLLATE utf8mb4_general_ci
                    AND c.tenant_id COLLATE utf8mb4_general_ci =
                       s.tenant_id COLLATE utf8mb4_general_ci
                LEFT JOIN restaurant_presence p
                    ON p.user_id COLLATE utf8mb4_general_ci =
                       s.created_by_user_id COLLATE utf8mb4_general_ci
                    AND p.tenant_id COLLATE utf8mb4_general_ci =
                       s.tenant_id COLLATE utf8mb4_general_ci
                WHERE s.tenant_id = ? AND s.game_type = 'battleground'
                    AND s.status = 'Forming'
                GROUP BY s.id, s.table_id, s.duration_seconds, s.max_players,
                    s.created_at, c.name, p.user_name
                ORDER BY s.created_at DESC LIMIT 30");
            $openStmt->bind_param("sss", $user_id, $user_id, $tenant_id);
            $openStmt->execute();
            $openResult = $openStmt->get_result();
            $openBattlegrounds = [];
            while ($row = $openResult->fetch_assoc()) {
                $row['squad_id'] = (int)$row['squad_id'];
                $row['table_id'] = (int)$row['table_id'];
                $row['duration_seconds'] = (int)$row['duration_seconds'];
                $row['max_players'] = (int)$row['max_players'];
                $row['joined_count'] = (int)$row['joined_count'];
                $row['is_host'] = (bool)$row['is_host'];
                $openBattlegrounds[] = $row;
            }
            $openStmt->close();
            echo json_encode([
                "status" => "success",
                "battlegrounds" => $openBattlegrounds
            ]);
            break;

        case 'request_battleground_join':
            $data = json_decode(file_get_contents('php://input'));
            $user_id = trim((string)(authenticatedCustomerEmail($conn, $tenant_id) ?? ''));
            $squad_id = (int)($data->squad_id ?? 0);
            if ($user_id === '' || $squad_id <= 0) {
                http_response_code($user_id === '' ? 401 : 400);
                echo json_encode(["status" => "error", "message" => $user_id === ''
                    ? "Sign in to request to join"
                    : "Invalid Battleground"]);
                exit;
            }
            if (!checkRateLimit($conn, $user_id, 'request_battleground_join', 5, 60)) {
                http_response_code(429);
                echo json_encode(["status" => "error", "message" => "Too many join requests. Please wait a minute."]);
                exit;
            }

            $conn->begin_transaction();
            try {
                $squadStmt = $conn->prepare("SELECT created_by_user_id, status, max_players
                    FROM game_squads WHERE id = ? AND tenant_id = ?
                        AND game_type = 'battleground' FOR UPDATE");
                $squadStmt->bind_param("is", $squad_id, $tenant_id);
                $squadStmt->execute();
                $squad = $squadStmt->get_result()->fetch_assoc();
                $squadStmt->close();
                if (!$squad || $squad['status'] !== 'Forming') {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "This Battleground is no longer open"]);
                    exit;
                }
                if (strcasecmp($squad['created_by_user_id'], $user_id) === 0) {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "You already host this Battleground"]);
                    exit;
                }

                $presenceStmt = $conn->prepare("SELECT 1 FROM restaurant_presence
                    WHERE tenant_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci
                        AND user_id COLLATE utf8mb4_general_ci = ? COLLATE utf8mb4_general_ci
                        AND last_seen > (NOW() - INTERVAL 5 MINUTE) LIMIT 1");
                $presenceStmt->bind_param("ss", $tenant_id, $user_id);
                $presenceStmt->execute();
                $isNearby = $presenceStmt->get_result()->num_rows > 0;
                $presenceStmt->close();
                if (!$isNearby) {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "Check in to the venue to request joining"]);
                    exit;
                }

                $memberStmt = $conn->prepare("SELECT status FROM game_squad_members
                    WHERE squad_id = ? AND user_id COLLATE utf8mb4_general_ci =
                        ? COLLATE utf8mb4_general_ci LIMIT 1 FOR UPDATE");
                $memberStmt->bind_param("is", $squad_id, $user_id);
                $memberStmt->execute();
                $member = $memberStmt->get_result()->fetch_assoc();
                $memberStmt->close();
                if ($member && in_array($member['status'], ['Joined', 'Invited', 'JoinRequested'], true)) {
                    $conn->rollback();
                    $message = $member['status'] === 'Joined'
                        ? "You are already in this Battleground"
                        : ($member['status'] === 'Invited'
                            ? "You already have an invitation"
                            : "Your join request is waiting for the host");
                    echo json_encode(["status" => "error", "message" => $message]);
                    exit;
                }

                $capacityStmt = $conn->prepare("SELECT COUNT(*) AS cnt FROM game_squad_members
                    WHERE squad_id = ? AND status IN ('Joined', 'Invited', 'JoinRequested')");
                $capacityStmt->bind_param("i", $squad_id);
                $capacityStmt->execute();
                $capacity = (int)$capacityStmt->get_result()->fetch_assoc()['cnt'];
                $capacityStmt->close();
                if ($capacity >= (int)$squad['max_players']) {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "Battleground is full"]);
                    exit;
                }

                if ($member) {
                    $saveStmt = $conn->prepare("UPDATE game_squad_members
                        SET status = 'JoinRequested', member_source = 'nearby',
                            responded_at = NULL
                        WHERE squad_id = ? AND user_id COLLATE utf8mb4_general_ci =
                            ? COLLATE utf8mb4_general_ci");
                    $saveStmt->bind_param("is", $squad_id, $user_id);
                } else {
                    $saveStmt = $conn->prepare("INSERT INTO game_squad_members
                        (squad_id, user_id, status, member_source)
                        VALUES (?, ?, 'JoinRequested', 'nearby')");
                    $saveStmt->bind_param("is", $squad_id, $user_id);
                }
                if (!$saveStmt->execute()) {
                    throw new RuntimeException("Could not save join request");
                }
                $saveStmt->close();

                $notificationStmt = $conn->prepare("INSERT INTO notifications
                    (tenant_id, user_id, title, message, type, sender_id, related_squad_id)
                    VALUES (?, ?, 'Battleground join request', ?, 'squad_join_request', ?, ?)");
                $requestMessage = $user_id . " wants to join your Battleground.";
                $notificationStmt->bind_param(
                    "ssssi",
                    $tenant_id,
                    $squad['created_by_user_id'],
                    $requestMessage,
                    $user_id,
                    $squad_id
                );
                $notificationStmt->execute();
                $notificationStmt->close();
                $conn->commit();
                echo json_encode(["status" => "success", "message" => "Join request sent to the host"]);
            } catch (Throwable $e) {
                $conn->rollback();
                throw $e;
            }
            break;

        case 'get_battleground_join_requests':
            $user_id = trim((string)(authenticatedCustomerEmail($conn, $tenant_id) ?? ''));
            $squad_id = (int)($_GET['squad_id'] ?? 0);
            if ($user_id === '' || $squad_id <= 0) {
                http_response_code($user_id === '' ? 401 : 400);
                echo json_encode(["status" => "error", "message" => "Sign in as the host to view requests"]);
                exit;
            }
            $hostStmt = $conn->prepare("SELECT 1 FROM game_squads
                WHERE id = ? AND tenant_id = ? AND game_type = 'battleground'
                    AND created_by_user_id COLLATE utf8mb4_general_ci =
                        ? COLLATE utf8mb4_general_ci LIMIT 1");
            $hostStmt->bind_param("iss", $squad_id, $tenant_id, $user_id);
            $hostStmt->execute();
            $isHost = $hostStmt->get_result()->num_rows > 0;
            $hostStmt->close();
            if (!$isHost) {
                http_response_code(403);
                echo json_encode(["status" => "error", "message" => "Only the host can view join requests"]);
                exit;
            }
            $requestsStmt = $conn->prepare("SELECT m.user_id,
                    COALESCE(c.name, p.user_name, 'Diner') AS user_name,
                    m.invited_at
                FROM game_squad_members m
                LEFT JOIN game_squads s ON s.id = m.squad_id
                LEFT JOIN customers c
                    ON LOWER(c.email) COLLATE utf8mb4_general_ci =
                       LOWER(m.user_id) COLLATE utf8mb4_general_ci
                    AND c.tenant_id COLLATE utf8mb4_general_ci =
                       s.tenant_id COLLATE utf8mb4_general_ci
                LEFT JOIN restaurant_presence p
                    ON p.user_id COLLATE utf8mb4_general_ci =
                       m.user_id COLLATE utf8mb4_general_ci
                    AND p.tenant_id COLLATE utf8mb4_general_ci =
                       s.tenant_id COLLATE utf8mb4_general_ci
                WHERE m.squad_id = ? AND m.status = 'JoinRequested'
                ORDER BY m.invited_at ASC");
            $requestsStmt->bind_param("i", $squad_id);
            $requestsStmt->execute();
            $requests = $requestsStmt->get_result()->fetch_all(MYSQLI_ASSOC);
            $requestsStmt->close();
            echo json_encode(["status" => "success", "requests" => $requests]);
            break;

        case 'respond_to_battleground_join':
            $data = json_decode(file_get_contents('php://input'));
            $user_id = trim((string)(authenticatedCustomerEmail($conn, $tenant_id) ?? ''));
            $squad_id = (int)($data->squad_id ?? 0);
            $requester_id = trim((string)($data->requester_id ?? ''));
            $accept = (bool)($data->accept ?? false);
            if ($user_id === '' || $squad_id <= 0 || $requester_id === '') {
                http_response_code($user_id === '' ? 401 : 400);
                echo json_encode(["status" => "error", "message" => "Invalid join request action"]);
                exit;
            }

            $conn->begin_transaction();
            try {
                $squadStmt = $conn->prepare("SELECT created_by_user_id, status, max_players
                    FROM game_squads WHERE id = ? AND tenant_id = ?
                        AND game_type = 'battleground' FOR UPDATE");
                $squadStmt->bind_param("is", $squad_id, $tenant_id);
                $squadStmt->execute();
                $squad = $squadStmt->get_result()->fetch_assoc();
                $squadStmt->close();
                if (!$squad || strcasecmp($squad['created_by_user_id'], $user_id) !== 0) {
                    $conn->rollback();
                    http_response_code(403);
                    echo json_encode(["status" => "error", "message" => "Only the host can respond to join requests"]);
                    exit;
                }
                if ($squad['status'] !== 'Forming') {
                    $conn->rollback();
                    http_response_code(409);
                    echo json_encode(["status" => "error", "message" => "This Battleground has already started"]);
                    exit;
                }
                $requestStmt = $conn->prepare("SELECT status FROM game_squad_members
                    WHERE squad_id = ? AND user_id COLLATE utf8mb4_general_ci =
                        ? COLLATE utf8mb4_general_ci FOR UPDATE");
                $requestStmt->bind_param("is", $squad_id, $requester_id);
                $requestStmt->execute();
                $request = $requestStmt->get_result()->fetch_assoc();
                $requestStmt->close();
                if (!$request || $request['status'] !== 'JoinRequested') {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "This join request is no longer pending"]);
                    exit;
                }

                if ($accept) {
                    $capacityStmt = $conn->prepare("SELECT COUNT(*) AS cnt FROM game_squad_members
                        WHERE squad_id = ? AND status IN ('Joined', 'Invited', 'JoinRequested')");
                    $capacityStmt->bind_param("i", $squad_id);
                    $capacityStmt->execute();
                    $capacity = (int)$capacityStmt->get_result()->fetch_assoc()['cnt'];
                    $capacityStmt->close();
                    if ($capacity > (int)$squad['max_players']) {
                        $conn->rollback();
                        echo json_encode(["status" => "error", "message" => "Battleground is full"]);
                        exit;
                    }
                }

                $newStatus = $accept ? 'Joined' : 'Declined';
                $updateStmt = $conn->prepare("UPDATE game_squad_members
                    SET status = ?, responded_at = NOW()
                    WHERE squad_id = ? AND user_id COLLATE utf8mb4_general_ci =
                        ? COLLATE utf8mb4_general_ci AND status = 'JoinRequested'");
                $updateStmt->bind_param("sis", $newStatus, $squad_id, $requester_id);
                $updateStmt->execute();
                $updateStmt->close();

                $notificationType = $accept ? 'squad_join_approved' : 'squad_join_declined';
                $notificationTitle = $accept ? 'Battleground request accepted' : 'Battleground request declined';
                $notificationMessage = $accept
                    ? 'Your request was accepted. Tap to open the Battleground lobby.'
                    : 'Your request to join the Battleground was declined.';
                $notificationStmt = $conn->prepare("INSERT INTO notifications
                    (tenant_id, user_id, title, message, type, sender_id, related_squad_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?)");
                $notificationStmt->bind_param(
                    "ssssssi",
                    $tenant_id,
                    $requester_id,
                    $notificationTitle,
                    $notificationMessage,
                    $notificationType,
                    $user_id,
                    $squad_id
                );
                $notificationStmt->execute();
                $notificationStmt->close();
                $conn->commit();
                echo json_encode([
                    "status" => "success",
                    "response" => $newStatus,
                    "message" => $accept ? "Diner joined the Battleground" : "Join request declined"
                ]);
            } catch (Throwable $e) {
                $conn->rollback();
                throw $e;
            }
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

            if ($squad['game_type'] !== 'battleground') {
                // Preserve the original Tap War behavior.
                $ord_stmt = $conn->prepare("SELECT status FROM orders WHERE tenant_id = ? AND user_id = ? ORDER BY id DESC LIMIT 1");
                $ord_stmt->bind_param("ss", $tenant_id, $user_id);
                $ord_stmt->execute();
                $ord_res = $ord_stmt->get_result();
                if ($ord_row = $ord_res->fetch_assoc()) {
                    if (strtolower($ord_row['status']) === 'ready' && $squad['status'] === 'InProgress') {
                        $l_stmt = $conn->prepare("UPDATE game_squad_members SET status = 'Left' WHERE squad_id = ? AND user_id = ?");
                        $l_stmt->bind_param("is", $squad_id, $user_id);
                        $l_stmt->execute();
                        $l_stmt->close();
                    }
                }
                $ord_stmt->close();
            }

            // Fetch members
            $m_stmt = $conn->prepare("SELECT m.user_id, m.status, m.member_source,
                                              COALESCE(c.name, p.user_name, 'Diner') as user_name
                                      FROM game_squad_members m
                                      LEFT JOIN customers c
                                        ON LOWER(c.email) COLLATE utf8mb4_general_ci =
                                           LOWER(m.user_id) COLLATE utf8mb4_general_ci
                                        AND c.tenant_id COLLATE utf8mb4_general_ci =
                                            ? COLLATE utf8mb4_general_ci
                                      LEFT JOIN restaurant_presence p
                                        ON p.user_id COLLATE utf8mb4_general_ci =
                                           m.user_id COLLATE utf8mb4_general_ci
                                        AND p.tenant_id COLLATE utf8mb4_general_ci =
                                            ? COLLATE utf8mb4_general_ci
                                      WHERE m.squad_id = ? AND m.status <> 'JoinRequested'");
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
            $conn->begin_transaction();
            $s_stmt = $conn->prepare("SELECT created_by_user_id, status, game_type FROM game_squads
                WHERE id = ? AND tenant_id = ? LIMIT 1 FOR UPDATE");
            $s_stmt->bind_param("is", $squad_id, $tenant_id);
            $s_stmt->execute();
            $s_res = $s_stmt->get_result();
            if ($s_row = $s_res->fetch_assoc()) {
                if (strcasecmp($s_row['created_by_user_id'], $user_id) !== 0) {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "Only the squad creator can start the game"]);
                    exit;
                }
                if ($s_row['status'] !== 'Forming') {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "Squad is already started or closed"]);
                    exit;
                }
            } else {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "Squad not found"]);
                exit;
            }
            $s_stmt->close();

            // Tap War keeps its original two-player minimum; Battleground needs three.
            $cnt_stmt = $conn->prepare("SELECT COUNT(*) as cnt FROM game_squad_members WHERE squad_id = ? AND status = 'Joined'");
            $cnt_stmt->bind_param("i", $squad_id);
            $cnt_stmt->execute();
            $cnt_row = $cnt_stmt->get_result()->fetch_assoc();
            $cnt_stmt->close();

            $minimumPlayers = $s_row['game_type'] === 'battleground' ? 3 : 2;
            if ((int)$cnt_row['cnt'] < $minimumPlayers) {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "At least $minimumPlayers joined members are required to start"]);
                exit;
            }

            // Set status to Ready / InProgress and start_at = NOW() + 5 seconds
            $upd = $conn->prepare("UPDATE game_squads SET status = 'InProgress', started_at = NOW(), start_at = DATE_ADD(NOW(), INTERVAL 5 SECOND) WHERE id = ? AND status = 'Forming'");
            $upd->bind_param("i", $squad_id);
            if ($upd->execute()) {
                $conn->commit();
                echo json_encode(["status" => "success", "message" => "Game starting"]);
            } else {
                $conn->rollback();
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

            $modeStmt = $conn->prepare("SELECT game_type FROM game_squads WHERE id = ? AND tenant_id = ? LIMIT 1");
            $modeStmt->bind_param("is", $squad_id, $tenant_id);
            $modeStmt->execute();
            $mode = $modeStmt->get_result()->fetch_assoc();
            $modeStmt->close();
            if ($mode && $mode['game_type'] === 'battleground') {
                echo json_encode(["status" => "error", "message" => "Battleground scores are submitted once at match end"]);
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

        case 'submit_final_score':
            $data = json_decode(file_get_contents('php://input'));
            $user_id = trim((string)(authenticatedCustomerEmail($conn, $tenant_id) ?? ''));
            $squad_id = (int)($data->squad_id ?? 0);
            $tap_value = $data->tap_count ?? null;
            if ($user_id === '') {
                http_response_code(401);
                echo json_encode(["status" => "error", "message" => "Sign in to submit a Battleground score"]);
                exit;
            }
            if ($squad_id <= 0 || (!is_int($tap_value) && !is_string($tap_value)) ||
                !preg_match('/^\d+$/', (string)$tap_value) ||
                filter_var((string)$tap_value, FILTER_VALIDATE_INT) === false) {
                echo json_encode(["status" => "error", "message" => "Invalid final score"]);
                exit;
            }
            if (!checkRateLimit($conn, $user_id, 'final_score_' . $squad_id, 1, 60)) {
                http_response_code(429);
                echo json_encode(["status" => "error", "message" => "Final score was already submitted"]);
                exit;
            }
            $tap_count = (int)$tap_value;
            $reachedAt = null;
            $reachedAtInput = trim((string)($data->reached_at_timestamp ?? ''));
            if ($reachedAtInput !== '') {
                try {
                    $parsedReachedAt = new DateTimeImmutable($reachedAtInput);
                    $reachedAt = $parsedReachedAt
                        ->setTimezone(new DateTimeZone('UTC'))
                        ->format('Y-m-d H:i:s.u');
                } catch (Throwable $e) {
                    $reachedAt = null;
                }
            }

            $conn->begin_transaction();
            try {
                $squadStmt = $conn->prepare("SELECT game_type, status, duration_seconds
                    FROM game_squads WHERE id = ? AND tenant_id = ? FOR UPDATE");
                $squadStmt->bind_param("is", $squad_id, $tenant_id);
                $squadStmt->execute();
                $squadRow = $squadStmt->get_result()->fetch_assoc();
                $squadStmt->close();
                if (!$squadRow || $squadRow['game_type'] !== 'battleground') {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "Battleground not found"]);
                    exit;
                }
                if ($squadRow['status'] !== 'InProgress') {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "Battleground is not accepting scores"]);
                    exit;
                }
                $memberStmt = $conn->prepare("SELECT user_id FROM game_squad_members
                    WHERE squad_id = ? AND LOWER(user_id) = LOWER(?) AND status = 'Joined' LIMIT 1");
                $memberStmt->bind_param("is", $squad_id, $user_id);
                $memberStmt->execute();
                $memberRow = $memberStmt->get_result()->fetch_assoc();
                $memberStmt->close();
                if (!$memberRow) {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "You are not a joined member of this Battleground"]);
                    exit;
                }
                $alreadyStmt = $conn->prepare("SELECT id FROM game_squad_scores WHERE squad_id = ? AND user_id = ? LIMIT 1");
                $alreadyStmt->bind_param("is", $squad_id, $memberRow['user_id']);
                $alreadyStmt->execute();
                $alreadySubmitted = $alreadyStmt->get_result()->num_rows > 0;
                $alreadyStmt->close();
                if ($alreadySubmitted) {
                    $conn->rollback();
                    echo json_encode(["status" => "error", "message" => "Final score was already submitted"]);
                    exit;
                }

                $maxAllowed = (int)$squadRow['duration_seconds'] * MAX_HUMAN_TAPS_PER_SECOND;
                $disqualified = $tap_count > $maxAllowed ? 1 : 0;
                if ($disqualified) {
                    error_log("Battleground score disqualified: user_id={$memberRow['user_id']} squad_id={$squad_id} submitted_tap_count={$tap_count} max_allowed={$maxAllowed}");
                }
                $scoreStmt = $conn->prepare("INSERT INTO game_squad_scores
                    (squad_id, user_id, tap_count, disqualified, reached_at_timestamp, is_dnf)
                    VALUES (?, ?, ?, ?, ?, 0)");
                $scoreStmt->bind_param("isiis", $squad_id, $memberRow['user_id'], $tap_count, $disqualified, $reachedAt);
                $scoreStmt->execute();
                $scoreStmt->close();
                $conn->commit();
            } catch (Throwable $e) {
                $conn->rollback();
                throw $e;
            }
            resolveBattlegroundIfReady($conn, $tenant_id, $squad_id);
            echo json_encode([
                "status" => "success",
                "disqualified" => (bool)$disqualified,
                "max_possible_taps" => $maxAllowed
            ]);
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
                if ($res['member_status'] === 'Invited' && $res['status'] !== 'Forming') {
                    http_response_code(409);
                    echo json_encode(["status" => "error", "message" => "This Battleground has already started; the invite is closed"]);
                    exit;
                }
                // Opening a pending invite accepts it while the roster is still forming.
                if ($res['member_status'] === 'Invited') {
                    $conn->begin_transaction();
                    $lockStmt = $conn->prepare("SELECT status, max_players FROM game_squads
                        WHERE id = ? AND tenant_id = ? FOR UPDATE");
                    $lockStmt->bind_param("is", $res['id'], $tenant_id);
                    $lockStmt->execute();
                    $lockedSquad = $lockStmt->get_result()->fetch_assoc();
                    $lockStmt->close();
                    if (!$lockedSquad || $lockedSquad['status'] !== 'Forming') {
                        $conn->rollback();
                        http_response_code(409);
                        echo json_encode(["status" => "error", "message" => "This Battleground has already started; the invite is closed"]);
                        exit;
                    }
                    $slotStmt = $conn->prepare("SELECT COUNT(*) AS cnt FROM game_squad_members
                        WHERE squad_id = ? AND status IN ('Joined', 'Invited')");
                    $slotStmt->bind_param("i", $res['id']);
                    $slotStmt->execute();
                    $slotCount = (int)$slotStmt->get_result()->fetch_assoc()['cnt'];
                    $slotStmt->close();
                    if ($slotCount > (int)$lockedSquad['max_players']) {
                        $conn->rollback();
                        echo json_encode(["status" => "error", "message" => "Battleground is full"]);
                        exit;
                    }
                    $u_stmt = $conn->prepare("UPDATE game_squad_members SET status = 'Joined', responded_at = NOW() WHERE squad_id = ? AND user_id = ?");
                    $u_stmt->bind_param("is", $res['id'], $user_id);
                    $u_stmt->execute();
                    $u_stmt->close();
                    $conn->commit();
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

            $s_stmt = $conn->prepare("SELECT status, game_type, start_at, started_at, duration_seconds, result_json
                FROM game_squads WHERE id = ? AND tenant_id = ? LIMIT 1");
            $s_stmt->bind_param("is", $squad_id, $tenant_id);
            $s_stmt->execute();
            $squad = $s_stmt->get_result()->fetch_assoc();
            $s_stmt->close();

            if (!$squad) {
                echo json_encode(["status" => "error", "message" => "Squad not found"]);
                exit;
            }
            if ($squad['game_type'] === 'battleground') {
                resolveBattlegroundIfReady($conn, $tenant_id, $squad_id);
                $s_stmt = $conn->prepare("SELECT status, game_type, start_at, started_at, duration_seconds, result_json
                    FROM game_squads WHERE id = ? AND tenant_id = ? LIMIT 1");
                $s_stmt->bind_param("is", $squad_id, $tenant_id);
                $s_stmt->execute();
                $squad = $s_stmt->get_result()->fetch_assoc();
                $s_stmt->close();
            }

            // Fetch scores and members
            $sc_stmt = $conn->prepare("SELECT s.user_id, s.tap_count, s.disqualified, s.reached_at_timestamp, s.is_dnf,
                                              m.status, COALESCE(c.name, p.user_name, 'Diner') as user_name
                                       FROM game_squad_scores s
                                       JOIN game_squad_members m ON m.squad_id = s.squad_id AND m.user_id = s.user_id
                                       LEFT JOIN customers c
                                         ON LOWER(c.email) COLLATE utf8mb4_general_ci =
                                            LOWER(s.user_id) COLLATE utf8mb4_general_ci
                                         AND c.tenant_id COLLATE utf8mb4_general_ci =
                                             ? COLLATE utf8mb4_general_ci
                                       LEFT JOIN restaurant_presence p
                                         ON p.user_id COLLATE utf8mb4_general_ci =
                                            s.user_id COLLATE utf8mb4_general_ci
                                         AND p.tenant_id COLLATE utf8mb4_general_ci =
                                             ? COLLATE utf8mb4_general_ci
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
                "game_type" => $squad['game_type'],
                "start_at" => $squad['start_at'],
                "duration_seconds" => (int)$squad['duration_seconds'],
                "scores" => $scores,
                "result" => $squad['game_type'] === 'battleground'
                    ? json_decode($squad['result_json'] ?? 'null', true)
                    : null
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
