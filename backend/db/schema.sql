-- Anurag_Rishi — MySQL schema
-- Run with: mysql -u root -p < db/schema.sql  (or `npm run migrate`)

CREATE DATABASE IF NOT EXISTS anurag_rishi
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE anurag_rishi;

-- ---------------------------------------------------------------------------
-- Users
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email           VARCHAR(255)    NOT NULL,
  display_name    VARCHAR(120)    NOT NULL,
  password_hash   VARCHAR(255)    NOT NULL,
  role            ENUM('user','admin') NOT NULL DEFAULT 'user',
  -- The device this account is locked to. NULL until first successful login.
  bound_device_id VARCHAR(128)    NULL,
  is_active       TINYINT(1)      NOT NULL DEFAULT 1,
  created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email),
  KEY idx_users_bound_device (bound_device_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- Devices — every device that has ever attempted login for a user.
-- Gives you an audit trail and the data to build a "deregister device" flow.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS devices (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id       BIGINT UNSIGNED NOT NULL,
  device_id     VARCHAR(128)    NOT NULL,  -- the app's stable fingerprint
  platform      VARCHAR(32)     NULL,      -- 'android' | 'ios'
  model         VARCHAR(120)    NULL,
  os_version    VARCHAR(60)     NULL,
  first_seen_ip VARCHAR(45)     NULL,      -- IPv4/IPv6 of first sign-in
  last_seen_ip  VARCHAR(45)     NULL,
  first_seen_at TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_devices_user_device (user_id, device_id),
  KEY idx_devices_user (user_id),
  CONSTRAINT fk_devices_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- Login audit — one row per login attempt (success or rejection).
-- This is the IP / device history you asked to "store".
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS login_audit (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     BIGINT UNSIGNED NULL,
  email       VARCHAR(255)    NULL,
  device_id   VARCHAR(128)    NULL,
  ip_address  VARCHAR(45)     NULL,
  user_agent  VARCHAR(255)    NULL,
  -- 'success' | 'bad_credentials' | 'device_locked' | 'inactive'
  outcome     VARCHAR(32)     NOT NULL,
  created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_login_audit_user (user_id),
  KEY idx_login_audit_created (created_at)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- Media — videos and audio in the catalog.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS media (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  title         VARCHAR(255)    NOT NULL,
  description   TEXT            NULL,
  media_type    ENUM('video','audio') NOT NULL,
  -- File name (relative to MEDIA_DIR). Served only through the auth-checked endpoint.
  file_key      VARCHAR(512)    NOT NULL,
  thumbnail_url VARCHAR(1024)   NULL,
  duration_secs INT UNSIGNED    NULL,
  is_downloadable TINYINT(1)    NOT NULL DEFAULT 1,
  is_published  TINYINT(1)      NOT NULL DEFAULT 1,
  created_at    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_media_type (media_type),
  KEY idx_media_published (is_published)
) ENGINE=InnoDB;
