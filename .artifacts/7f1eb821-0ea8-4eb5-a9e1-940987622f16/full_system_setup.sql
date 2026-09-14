-- ==========================================================
-- 🚀 FULL SYSTEM SQL SETUP - CHIYABREAK (V3 - Advanced Social)
-- Includes: Onboarding, Gender, Following, Requests & Friends
-- ==========================================================

-- 1. LOYALTY & REWARDS SYSTEM
CREATE TABLE IF NOT EXISTS loyalty_settings (
    tenant_id VARCHAR(50) PRIMARY KEY,
    points_per_order_fixed INT DEFAULT 50,
    points_per_amount DECIMAL(10,2) DEFAULT 0.05,
    group_join_bonus INT DEFAULT 200,
    mystery_box_enabled TINYINT(1) DEFAULT 1,
    min_redeem_points INT DEFAULT 100,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

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

CREATE TABLE IF NOT EXISTS reward_claims (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(100) NOT NULL,
    reward_id INT NOT NULL,
    claim_code VARCHAR(20) UNIQUE NOT NULL,
    status ENUM('Pending', 'Claimed', 'Expired') DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    claimed_at TIMESTAMP NULL
);

-- 2. CUSTOMER IDENTITY & ONBOARDING
CREATE TABLE IF NOT EXISTS customers (
    email VARCHAR(100) NOT NULL, -- Stores Email or Guest ID
    tenant_id VARCHAR(50) NOT NULL,
    pin VARCHAR(10) DEFAULT NULL,
    name VARCHAR(100) DEFAULT 'Guest',
    gender ENUM('Male', 'Female', 'Other') DEFAULT 'Male',
    is_anonymous TINYINT(1) DEFAULT 0,
    points INT DEFAULT 0,
    order_count INT DEFAULT 0,
    fcm_token TEXT DEFAULT NULL, -- Stores unique device ID for push notifications
    last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (email, tenant_id)
);

-- 3. MENU & PRODUCTS SYSTEM
CREATE TABLE IF NOT EXISTS categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    title VARCHAR(100) NOT NULL,
    rank INT DEFAULT 0,
    icon VARCHAR(50) DEFAULT 'restaurant_menu',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    category_id INT NOT NULL,
    title VARCHAR(150) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    image_url TEXT,
    description TEXT,
    slogan VARCHAR(255),
    featured_section ENUM('none', 'just_for_you', 'trending', 'popular') DEFAULT 'none',
    model_url TEXT,
    ios_model_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS order_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

-- 4. ORDERING SYSTEM
CREATE TABLE IF NOT EXISTS restaurant_tables (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    table_number INT NOT NULL,
    status ENUM('Available', 'Dining', 'Reserved') DEFAULT 'Available',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(tenant_id, table_number)
);

CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(100) DEFAULT NULL,
    customer_email VARCHAR(100) DEFAULT NULL,
    table_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status ENUM('Pending', 'Approved', 'Preparing', 'Ready', 'OnWay', 'Completed', 'Cancelled') DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 4. SOCIAL GRAPH (V2)
CREATE TABLE IF NOT EXISTS user_follows (
    id INT AUTO_INCREMENT PRIMARY KEY,
    follower_id VARCHAR(100) NOT NULL, -- Who is clicking Follow
    following_id VARCHAR(100) NOT NULL, -- Who is being followed
    tenant_id VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(follower_id, following_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS restaurant_presence (
    user_id VARCHAR(100) NOT NULL,
    tenant_id VARCHAR(50) NOT NULL,
    table_number INT NOT NULL,
    user_name VARCHAR(100) DEFAULT 'Guest',
    user_image VARCHAR(255) DEFAULT '',
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, tenant_id)
);

CREATE TABLE IF NOT EXISTS user_waves (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sender_id VARCHAR(100) NOT NULL,
    receiver_id VARCHAR(100) NOT NULL,
    tenant_id VARCHAR(50) NOT NULL,
    is_delivered TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS notifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(100) NOT NULL, -- Receiver (Guest ID or Email)
    title VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    type ENUM('order', 'points', 'follow', 'wave', 'message') NOT NULL,
    sender_id VARCHAR(100) DEFAULT NULL,
    is_read TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
