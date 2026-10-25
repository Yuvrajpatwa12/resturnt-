CREATE TABLE IF NOT EXISTS customer_auth_sessions (
    token_hash CHAR(64) NOT NULL PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    email VARCHAR(190) NOT NULL,
    expires_at DATETIME NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_customer_auth_lookup (tenant_id, email, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS customer_notification_email_preferences (
    tenant_id VARCHAR(50) NOT NULL,
    email VARCHAR(190) NOT NULL,
    email_enabled TINYINT(1) NOT NULL DEFAULT 0,
    email_follow TINYINT(1) NOT NULL DEFAULT 1,
    email_wave TINYINT(1) NOT NULL DEFAULT 1,
    email_message TINYINT(1) NOT NULL DEFAULT 1,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_id, email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS notification_email_queue (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    user_id VARCHAR(190) NOT NULL,
    notification_id BIGINT NOT NULL,
    event_type VARCHAR(32) NOT NULL,
    status ENUM('pending', 'processing', 'sent', 'acknowledged', 'skipped', 'failed') NOT NULL DEFAULT 'pending',
    available_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processing_started_at TIMESTAMP NULL DEFAULT NULL,
    sent_at TIMESTAMP NULL DEFAULT NULL,
    attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
    last_error TEXT NULL,
    UNIQUE KEY uq_email_notification (tenant_id, notification_id),
    KEY idx_email_queue_due (status, available_at, created_at),
    KEY idx_email_queue_user (tenant_id, user_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
