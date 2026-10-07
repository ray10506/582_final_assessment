-- HonestDrive database schema
-- MySQL 8.x
-- Matches app/project/__init__.py config: MYSQL_PORT 3307

CREATE DATABASE IF NOT EXISTS honestdrive
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE honestdrive;

-- ---------------------------------------------------------------------------
-- users: subscribers, campaign creators, and platform admins
-- ---------------------------------------------------------------------------
CREATE TABLE users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(100) NOT NULL,
  email         VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role          ENUM('subscriber', 'creator', 'admin') NOT NULL DEFAULT 'subscriber',
  status        ENUM('active', 'suspended') NOT NULL DEFAULT 'active',
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------------
-- campaigns: one per creator, shown on home/browse pages and admin review
-- ---------------------------------------------------------------------------
CREATE TABLE campaigns (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  creator_id     INT NOT NULL,
  title          VARCHAR(150) NOT NULL,
  category       VARCHAR(100),
  description    TEXT,
  image_path     VARCHAR(255),
  monthly_goal   DECIMAL(10, 2) NOT NULL DEFAULT 0,
  current_raised DECIMAL(10, 2) NOT NULL DEFAULT 0,
  status         ENUM('pending', 'active', 'paused', 'suspended', 'rejected') NOT NULL DEFAULT 'pending',
  is_featured    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (creator_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- tiers: subscription tiers offered by a campaign (e.g. Silver, Gold)
-- ---------------------------------------------------------------------------
CREATE TABLE tiers (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  campaign_id INT NOT NULL,
  name        VARCHAR(100) NOT NULL,
  price       DECIMAL(10, 2) NOT NULL,
  perks       TEXT,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- subscriptions: a user's recurring pledge to a campaign at a chosen tier
-- ---------------------------------------------------------------------------
CREATE TABLE subscriptions (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  user_id         INT NOT NULL,
  campaign_id     INT NOT NULL,
  tier_id         INT NOT NULL,
  payment_method  ENUM('credit_card', 'paypal') NOT NULL,
  public_message  TEXT,
  status          ENUM('active', 'cancelled') NOT NULL DEFAULT 'active',
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE,
  FOREIGN KEY (tier_id) REFERENCES tiers(id) ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------------
-- donations: individual charges against a subscription (payment history)
-- ---------------------------------------------------------------------------
CREATE TABLE donations (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  subscription_id INT NOT NULL,
  amount          DECIMAL(10, 2) NOT NULL,
  donated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (subscription_id) REFERENCES subscriptions(id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- posts: creator updates on the Campaign Management dashboard
-- ---------------------------------------------------------------------------
CREATE TABLE posts (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  campaign_id INT NOT NULL,
  title       VARCHAR(150) NOT NULL,
  content     TEXT,
  status      ENUM('visible', 'hidden') NOT NULL DEFAULT 'visible',
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- post_media: uploaded images/logs attached to a post
-- ---------------------------------------------------------------------------
CREATE TABLE post_media (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  post_id     INT NOT NULL,
  file_path   VARCHAR(255) NOT NULL,
  uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- comments: community wall comments, on a campaign or a specific post
-- ---------------------------------------------------------------------------
CREATE TABLE comments (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  user_id     INT NOT NULL,
  campaign_id INT,
  post_id     INT,
  content     TEXT NOT NULL,
  status      ENUM('visible', 'hidden') NOT NULL DEFAULT 'visible',
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (campaign_id) REFERENCES campaigns(id) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- reports: flagged comments/posts for admin moderation
-- ---------------------------------------------------------------------------
CREATE TABLE reports (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  reporter_id   INT,
  target_type   ENUM('comment', 'post') NOT NULL,
  target_id     INT NOT NULL,
  reason        VARCHAR(255) NOT NULL,
  report_count  INT NOT NULL DEFAULT 1,
  status        ENUM('pending', 'dismissed', 'resolved') NOT NULL DEFAULT 'pending',
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE SET NULL
);
