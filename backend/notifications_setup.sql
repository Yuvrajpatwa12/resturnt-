-- =======================================================
-- ChiyaBreak Notifications System Schema
-- =======================================================

-- 1. Notifications Table (Main table for all notifications)
CREATE TABLE IF NOT EXISTS notifications (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT,
    type VARCHAR(50) NOT NULL,
    is_read TINYINT(1) DEFAULT 0,
    sender_id VARCHAR(255) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_tenant_user (tenant_id, user_id),
    INDEX idx_type (type),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 2. Admin Notification Email Preferences
CREATE TABLE IF NOT EXISTS admin_notification_email_preferences (
    tenant_id VARCHAR(100) NOT NULL,
    admin_email VARCHAR(190) NOT NULL,
    email_enabled TINYINT(1) NOT NULL DEFAULT 1,
    email_support TINYINT(1) NOT NULL DEFAULT 1,
    email_order TINYINT(1) NOT NULL DEFAULT 1,
    email_stock TINYINT(1) NOT NULL DEFAULT 1,
    email_subscription TINYINT(1) NOT NULL DEFAULT 1,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, admin_email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 3. Stock Alerts Table (For kitchen low stock requests)
CREATE TABLE IF NOT EXISTS stock_alerts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    ingredient_name VARCHAR(255) NOT NULL,
    current_quantity DECIMAL(10,2) DEFAULT 0.00,
    unit VARCHAR(50) DEFAULT NULL,
    alert_type VARCHAR(50) NOT NULL DEFAULT 'low_stock',
    status VARCHAR(50) DEFAULT 'Pending',
    requested_by VARCHAR(100) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_tenant_status (tenant_id, status),
    INDEX idx_alert_type (alert_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
