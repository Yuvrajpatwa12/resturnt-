<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once 'db_config.php';

$tenant_id = $_GET['tenant_id'];
$range = $_GET['range'] ?? 'Month';
$today = $_GET['date'] ?? date('Y-m-d');

$start_date = '';
switch($range) {
    case 'Day': $start_date = $today; break;
    case 'Week': $start_date = date('Y-m-d', strtotime($today . ' -7 days')); break;
    case 'Year': $start_date = date('Y-m-d', strtotime($today . ' -1 year')); break;
    default: $start_date = date('Y-m-01', strtotime($today)); break;
}

try {
    // 1. Stats
    $q1 = $conn->prepare("SELECT COUNT(*) as count FROM users WHERE tenant_id = :tid");
    $q1->execute(['tid' => $tenant_id]);
    $total_staff = $q1->fetch(PDO::FETCH_ASSOC)['count'];

    $q2 = $conn->prepare("SELECT COUNT(*) as count FROM attendance WHERE tenant_id = :tid AND date = :today AND (status = 'P' OR status = 'HL')");
    $q2->execute(['tid' => $tenant_id, 'today' => $today]);
    $present_today = $q2->fetch(PDO::FETCH_ASSOC)['count'];

    $q3 = $conn->prepare("SELECT COUNT(*) as count FROM attendance WHERE tenant_id = :tid AND date = :today AND (status = 'A' OR status = 'NIA' OR status = 'UA')");
    $q3->execute(['tid' => $tenant_id, 'today' => $today]);
    $absent_today = $q3->fetch(PDO::FETCH_ASSOC)['count'];

    // 2. Chart Data
    $chart_stmt = $conn->prepare("SELECT date,
                 SUM(CASE WHEN status IN ('P', 'HL') THEN 1 ELSE 0 END) as present,
                 SUM(CASE WHEN status IN ('A', 'NIA', 'UA') THEN 1 ELSE 0 END) as absent
                 FROM attendance
                 WHERE tenant_id = :tid AND date >= :start
                 GROUP BY date
                 ORDER BY date ASC");
    $chart_stmt->execute(['tid' => $tenant_id, 'start' => $start_date]);
    $chart_data = $chart_stmt->fetchAll(PDO::FETCH_ASSOC);

    // 3. Distribution
    $dist_stmt = $conn->prepare("SELECT status, COUNT(*) as count
                FROM attendance
                WHERE tenant_id = :tid AND date >= :start
                GROUP BY status");
    $dist_stmt->execute(['tid' => $tenant_id, 'start' => $start_date]);
    $distribution = $dist_stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        "status" => "success",
        "stats" => [
            "total_staff" => $total_staff,
            "present_today" => $present_today,
            "absent_today" => $absent_today
        ],
        "chart_data" => $chart_data,
        "distribution" => $distribution
    ]);

} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Database error: " . $e->getMessage()]);
}
?>
