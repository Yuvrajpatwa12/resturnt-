-- =======================================================
-- ChiyaBreak Theme Settings System Schema
-- =======================================================
-- This adds comprehensive theme customization support to the tenants table
-- allowing restaurants to customize their app's appearance

-- Add theme-related columns to tenants table
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS theme_name VARCHAR(50) DEFAULT 'Default Blue';
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS secondary_color VARCHAR(7) DEFAULT '#002D62';
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS background_color VARCHAR(7) DEFAULT '#F8FAFC';
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS font_family VARCHAR(50) DEFAULT 'Inter';
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS border_radius DECIMAL(4,1) DEFAULT 16.0;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS dark_mode_enabled TINYINT(1) DEFAULT 0;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS theme_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

-- Update existing tenants with default theme values
UPDATE tenants 
SET 
    theme_name = 'Default Blue',
    secondary_color = '#002D62',
    background_color = '#F8FAFC',
    font_family = 'Inter',
    border_radius = 16.0,
    dark_mode_enabled = 0
WHERE theme_name IS NULL OR theme_name = '';
