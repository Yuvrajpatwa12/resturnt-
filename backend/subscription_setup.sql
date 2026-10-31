-- =======================================================
-- ChiyaBreak Subscription & Super Admin Security System Schema
-- =======================================================

-- 1. Ensure Subscription Columns on `tenants` Table
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS subscription_status VARCHAR(50) DEFAULT 'Trial';
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS trial_start DATETIME DEFAULT NULL;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS trial_end DATETIME DEFAULT NULL;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS subscription_start DATETIME DEFAULT NULL;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS subscription_end DATETIME DEFAULT NULL;

-- 2. Packages Table
CREATE TABLE IF NOT EXISTS subscription_packages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    duration_days INT NOT NULL DEFAULT 30,
    price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    perks TEXT DEFAULT NULL,
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Seed Default Subscription Packages if empty
INSERT INTO subscription_packages (id, name, duration_days, price, perks, is_active)
SELECT 1, '3 Days Free Trial', 3, 0.00, 'Full Feature Access • Auto Activated • No Credit Card Needed', 1
WHERE NOT EXISTS (SELECT 1 FROM subscription_packages WHERE id = 1);

INSERT INTO subscription_packages (id, name, duration_days, price, perks, is_active)
SELECT 2, 'Monthly Starter', 28, 799.00, 'Standard Features • 1 Store • POS Billing', 1
WHERE NOT EXISTS (SELECT 1 FROM subscription_packages WHERE id = 2);

INSERT INTO subscription_packages (id, name, duration_days, price, perks, is_active)
SELECT 3, '3 Months Pro', 84, 2396.52, 'Priority Support • Advanced Analytics • Staff & Inventory', 1
WHERE NOT EXISTS (SELECT 1 FROM subscription_packages WHERE id = 3);

INSERT INTO subscription_packages (id, name, duration_days, price, perks, is_active)
SELECT 4, '6 Months Enterprise', 168, 4793.04, 'Unlimited Access • Multi-Store Ready • Premium Modules', 1
WHERE NOT EXISTS (SELECT 1 FROM subscription_packages WHERE id = 4);

-- 3. Subscription Requests Table
CREATE TABLE IF NOT EXISTS subscription_requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(100) NOT NULL,
    package_id INT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Pending', -- 'Pending', 'Approved', 'Rejected'
    rejection_note TEXT DEFAULT NULL,
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_by VARCHAR(100) DEFAULT NULL,
    approved_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_tenant (tenant_id),
    INDEX idx_status (status),
    FOREIGN KEY (package_id) REFERENCES subscription_packages(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 4. Super Admins Table
CREATE TABLE IF NOT EXISTS super_admins (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL DEFAULT 'Super Admin',
    email VARCHAR(255) DEFAULT '',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Seed Default Root Super Admin (username: 'admin', password/pin: 'patwa' / '123456')
-- SHA256 of 'patwa' = 7247a329c36d2643a6d713c7ee80ef9a3cc028f8042eb631a0e1b6f68c345f35
INSERT INTO super_admins (username, password_hash, name)
SELECT 'admin', '7247a329c36d2643a6d713c7ee80ef9a3cc028f8042eb631a0e1b6f68c345f35', 'Yuvraj Patwa (Root Admin)'
WHERE NOT EXISTS (SELECT 1 FROM super_admins WHERE username = 'admin');

-- 5. Super Admin Sessions Table
CREATE TABLE IF NOT EXISTS super_admin_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    username VARCHAR(100) NOT NULL,
    expires_at DATETIME NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_token (token_hash)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
