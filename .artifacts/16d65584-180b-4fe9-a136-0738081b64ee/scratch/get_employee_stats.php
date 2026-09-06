<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

include_once 'db_config.php';

$user_id = (int)$_GET['user_id'];
$month = $_GET['month'] ?? date('Y-m');

$start = "$month-01";
$end = date('Y-m-t', strtotime($start));

// 1. Employee Info & Base Salary
$user = $conn->query("SELECT name, role, salary_amount, payment_cycle_days FROM users WHERE id = $user_id")->fetch_assoc();

// 2. Attendance Counts
$counts = $conn->query("SELECT
    SUM(CASE WHEN status = 'P' THEN 1 ELSE 0 END) as p_count,
    SUM(CASE WHEN status = 'A' THEN 1 ELSE 0 END) as a_count,
    SUM(CASE WHEN status = 'HL' THEN 0.5 ELSE 0 END) as hl_count,
    SUM(CASE WHEN status = 'NIA' THEN 1 ELSE 0 END) as nia_count,
    SUM(CASE WHEN status = 'UA' THEN 1 ELSE 0 END) as ua_count
    FROM attendance
    WHERE user_id = $user_id AND date BETWEEN '$start' AND '$end'
")->fetch_assoc();

$total_present = (float)$counts['p_count'] + (float)$counts['hl_count'];
$total_deductions = (float)$counts['a_count'] + (float)$counts['nia_count'] + (float)$counts['ua_count'] + (float)$counts['hl_count'];

// 3. Daily History
$history_res = $conn->query("SELECT date, status FROM attendance WHERE user_id = $user_id AND date BETWEEN '$start' AND '$end' ORDER BY date DESC");
$history = [];
while($row = $history_res->fetch_assoc()) {
    $history[] = $row;
}

echo json_encode([
    "status" => "success",
    "user" => $user,
    "stats" => [
        "present" => $total_present,
        "absent" => $total_deductions,
        "p_raw" => (int)$counts['p_count'],
        "a_raw" => (int)$counts['a_count'],
        "hl_raw" => (int)$counts['hl_count'],
        "nia_raw" => (int)$counts['nia_count'],
        "ua_raw" => (int)$counts['ua_count']
    ],
    "history" => $history
]);

$conn->close();
?>
