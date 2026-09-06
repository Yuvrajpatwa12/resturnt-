<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') exit;

include_once 'db_config.php';

$target_dir = "uploads/receipts/";
if (!file_exists($target_dir)) {
    mkdir($target_dir, 0777, true);
}

if (isset($_FILES['receipt'])) {
    $file_ext = pathinfo($_FILES['receipt']['name'], PATHINFO_EXTENSION);
    $new_filename = uniqid() . '.' . $file_ext;
    $target_file = $target_dir . $new_filename;

    if (move_uploaded_file($_FILES['receipt']['tmp_name'], $target_file)) {
        $full_url = "https://startupsgo.tech/saas_api/" . $target_file;
        echo json_encode(["status" => "success", "url" => $full_url]);
    } else {
        echo json_encode(["status" => "error", "message" => "Upload failed"]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "No file uploaded"]);
}
?>
