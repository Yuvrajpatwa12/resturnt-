-- Loyalty Settings Table
CREATE TABLE IF NOT EXISTS loyalty_settings (
    tenant_id VARCHAR(50) PRIMARY KEY,
    points_per_order_fixed INT DEFAULT 10,
    points_per_amount DECIMAL(10,2) DEFAULT 0.05, -- 5% of order amount
    group_join_bonus INT DEFAULT 200,
    mystery_box_enabled TINYINT(1) DEFAULT 1,
    min_redeem_points INT DEFAULT 100,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Redeemable Rewards Table
CREATE TABLE IF NOT EXISTS redeemable_rewards (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    title VARCHAR(100) NOT NULL,
    points_required INT NOT NULL,
    image_url VARCHAR(255),
    description TEXT,
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Reward Claims Record Table
CREATE TABLE IF NOT EXISTS reward_claims (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    user_id INT NOT NULL,
    reward_id INT NOT NULL,
    claim_code VARCHAR(20) UNIQUE NOT NULL,
    status ENUM('Pending', 'Claimed', 'Expired') DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    claimed_at TIMESTAMP NULL
);

-- Mystery Box Config
CREATE TABLE IF NOT EXISTS mystery_box_config (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    reward_name VARCHAR(100) NOT NULL,
    probability DECIMAL(5,2) DEFAULT 10.00, -- Chance of winning
    image_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add points to users table (Assume users table exists)
-- ALTER TABLE users ADD COLUMN loyalty_points INT DEFAULT 0;
