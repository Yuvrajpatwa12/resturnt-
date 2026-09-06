<?php
header("Content-Type: application/json; charset=UTF-8");
require_once 'db_config.php';

try {
    // 1. Create expenses_v3 table
    $conn->exec("CREATE TABLE IF NOT EXISTS expenses_v3 (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(50) NOT NULL,
        category VARCHAR(50),
        amount DECIMAL(10,2),
        payment_mode VARCHAR(50),
        vendor_id INT DEFAULT NULL,
        note TEXT,
        receipt_url VARCHAR(255),
        status ENUM('Pending', 'Approved', 'Rejected') DEFAULT 'Approved',
        date DATE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");

    // 2. Create vendors table
    $conn->exec("CREATE TABLE IF NOT EXISTS vendors (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(50) NOT NULL,
        name VARCHAR(100) NOT NULL,
        phone VARCHAR(20),
        email VARCHAR(100),
        total_due DECIMAL(10,2) DEFAULT 0.00,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");

    // 3. Create recurring_expenses table
    $conn->exec("CREATE TABLE IF NOT EXISTS recurring_expenses (
        id INT AUTO_INCREMENT PRIMARY KEY,
        tenant_id VARCHAR(50) NOT NULL,
        title VARCHAR(100),
        category VARCHAR(50),
        amount DECIMAL(10,2),
        frequency ENUM('Daily', 'Weekly', 'Monthly', 'Yearly'),
        next_due_date DATE,
        is_active TINYINT(1) DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");

    echo json_encode(["status" => "success", "message" => "Database tables created or already exist."]);

} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => "Database failure: " . $e->getMessage()]);
}
?>
