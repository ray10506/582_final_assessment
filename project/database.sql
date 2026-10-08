-- HonestDrive database schema
-- MySQL 8.x
-- Matches app/project/__init__.py config: MYSQL_PORT 3307

CREATE DATABASE IF NOT EXISTS honestdrive
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE honestdrive;

-- Drop in reverse dependency order so the script can be re-run.
DROP TABLE IF EXISTS Report;
DROP TABLE IF EXISTS Comment;
DROP TABLE IF EXISTS Vote;
DROP TABLE IF EXISTS VehicleCandidate;
DROP TABLE IF EXISTS Poll;
DROP TABLE IF EXISTS PostAttachment;
DROP TABLE IF EXISTS Post;
DROP TABLE IF EXISTS Subscription;
DROP TABLE IF EXISTS Tier;
DROP TABLE IF EXISTS Campaign;
DROP TABLE IF EXISTS Category;
DROP TABLE IF EXISTS `User`;

-- =========================================================
-- Tables
-- =========================================================

CREATE TABLE `User` (
  id             VARCHAR(20)  NOT NULL,
  name           VARCHAR(100) NOT NULL,
  email          VARCHAR(255) NOT NULL,
  password       VARCHAR(255) NOT NULL,
  role           VARCHAR(20)  NOT NULL,
  channelName    VARCHAR(100),
  bio            TEXT,
  bannerImageURL VARCHAR(255),
  accountStatus  VARCHAR(20)  NOT NULL DEFAULT 'Active',
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_email (email)
);

CREATE TABLE Category (
  id          VARCHAR(20)  NOT NULL,
  name        VARCHAR(100) NOT NULL,
  description TEXT,
  PRIMARY KEY (id)
);

CREATE TABLE Campaign (
  id            VARCHAR(20)   NOT NULL,
  title         VARCHAR(150)  NOT NULL,
  description   TEXT,
  monthlyGoal   DECIMAL(10,2) NOT NULL,
  currentRaised DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  status        VARCHAR(20)   NOT NULL DEFAULT 'Pending',
  featured      BOOLEAN       NOT NULL DEFAULT FALSE,
  categoryID    VARCHAR(20)   NOT NULL,
  creatorID     VARCHAR(20)   NOT NULL,
  imagePath     VARCHAR(255),
  PRIMARY KEY (id),
  FOREIGN KEY (categoryID) REFERENCES Category(id),
  FOREIGN KEY (creatorID)  REFERENCES `User`(id)
);

CREATE TABLE Tier (
  id         VARCHAR(20)   NOT NULL,
  campaignID VARCHAR(20)   NOT NULL,
  name       VARCHAR(50)   NOT NULL,
  price      DECIMAL(10,2) NOT NULL,
  perks      TEXT,
  PRIMARY KEY (id),
  FOREIGN KEY (campaignID) REFERENCES Campaign(id) ON DELETE CASCADE
);

CREATE TABLE Subscription (
  id            VARCHAR(20)   NOT NULL,
  subscriberID  VARCHAR(20)   NOT NULL,
  campaignID    VARCHAR(20)   NOT NULL,
  tierID        VARCHAR(20)   NOT NULL,
  amount        DECIMAL(10,2) NOT NULL,
  paymentMethod VARCHAR(30),
  message       TEXT,
  isAnonymous   BOOLEAN       NOT NULL DEFAULT FALSE,
  status        VARCHAR(20)   NOT NULL DEFAULT 'Active',
  startDate     DATE,
  cancelledDate DATE,
  PRIMARY KEY (id),
  FOREIGN KEY (subscriberID) REFERENCES `User`(id),
  FOREIGN KEY (campaignID)   REFERENCES Campaign(id),
  FOREIGN KEY (tierID)       REFERENCES Tier(id)
);

CREATE TABLE Post (
  id          VARCHAR(20)  NOT NULL,
  campaignID  VARCHAR(20)  NOT NULL,
  title       VARCHAR(150) NOT NULL,
  description TEXT,
  visibility  VARCHAR(20)  NOT NULL DEFAULT 'Public',
  datePosted  DATE         NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (campaignID) REFERENCES Campaign(id) ON DELETE CASCADE
);

-- Composite PK: one row per file attached to a post (1NF).
CREATE TABLE PostAttachment (
  postID   VARCHAR(20)  NOT NULL,
  fileURL  VARCHAR(255) NOT NULL,
  fileType VARCHAR(100) NOT NULL,
  PRIMARY KEY (postID, fileURL),
  FOREIGN KEY (postID) REFERENCES Post(id) ON DELETE CASCADE
);

CREATE TABLE Poll (
  id         VARCHAR(20)  NOT NULL,
  campaignID VARCHAR(20)  NOT NULL,
  question   VARCHAR(255) NOT NULL,
  status     VARCHAR(20)  NOT NULL DEFAULT 'Pending',
  PRIMARY KEY (id),
  FOREIGN KEY (campaignID) REFERENCES Campaign(id) ON DELETE CASCADE
);

CREATE TABLE VehicleCandidate (
  id          VARCHAR(20)  NOT NULL,
  pollID      VARCHAR(20)  NOT NULL,
  vehicleName VARCHAR(150) NOT NULL,
  imageURL    VARCHAR(255),
  PRIMARY KEY (id),
  UNIQUE KEY uq_candidate_poll (id, pollID),
  FOREIGN KEY (pollID) REFERENCES Poll(id) ON DELETE CASCADE
);

-- Composite PK (pollID, subscriberID): one vote per subscriber per poll.
-- The (candidateID, pollID) FK guarantees the chosen candidate belongs to that poll.
CREATE TABLE Vote (
  pollID       VARCHAR(20) NOT NULL,
  subscriberID VARCHAR(20) NOT NULL,
  candidateID  VARCHAR(20) NOT NULL,
  dateVoted    DATE        NOT NULL,
  PRIMARY KEY (pollID, subscriberID),
  FOREIGN KEY (pollID)       REFERENCES Poll(id) ON DELETE CASCADE,
  FOREIGN KEY (subscriberID) REFERENCES `User`(id),
  FOREIGN KEY (candidateID, pollID) REFERENCES VehicleCandidate(id, pollID)
);

CREATE TABLE Comment (
  id           VARCHAR(20) NOT NULL,
  campaignID   VARCHAR(20) NOT NULL,
  subscriberID VARCHAR(20) NOT NULL,
  text         TEXT        NOT NULL,
  datePosted   DATE        NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (campaignID)   REFERENCES Campaign(id) ON DELETE CASCADE,
  FOREIGN KEY (subscriberID) REFERENCES `User`(id)
);

-- contentID points at a Comment, Post, User or Campaign depending on contentType,
-- so it cannot carry a single foreign key.
CREATE TABLE Report (
  id          VARCHAR(20)  NOT NULL,
  contentType VARCHAR(20)  NOT NULL,
  contentID   VARCHAR(20)  NOT NULL,
  reason      VARCHAR(255) NOT NULL,
  reportCount INT          NOT NULL DEFAULT 1,
  status      VARCHAR(20)  NOT NULL DEFAULT 'Pending',
  PRIMARY KEY (id)
);

-- =========================================================
-- Sample data
-- =========================================================

-- Passwords are placeholders; the sample data does not include them.
INSERT INTO `User` (id, name, email, password, role, accountStatus) VALUES
  ('U001', 'bbbbbbb Smith', 'john@voltlab.com',       'changeme', 'User',    'Active'),
  ('U002', 'Sarah M.',   'sarah.m@email.com',      'changeme', 'Supporter', 'Active'),
  ('U003', 'Mike R.',    'mike.r@email.com',       'changeme', 'Supporter', 'Active'),
  ('U004', 'Admin Root', 'admin@honestdrive.com',  'changeme', 'Administrator', 'Active'),
  ('U005', 'PR Bot',     'spam@carbrand.com',      'changeme', 'Fundraiser', 'Suspended');

INSERT INTO Category (id, name, description) VALUES
  ('CAT_01', 'EV Testing',  'Long-term electric vehicle battery and motor teardowns.'),
  ('CAT_02', 'Used Cars',   'Maintenance analysis of out-of-warranty luxury vehicles.'),
  ('CAT_03', 'SUVs & 4x4',  'Off-road capability and suspension durability testing.'),
  ('CAT_04', 'Performance', 'Track day stress tests and aftermarket parts reviews.'),
  ('CAT_05', 'Economy',     'Real-world MPG and daily commuter running costs.');

INSERT INTO Campaign (id, title, monthlyGoal, currentRaised, status, categoryID, creatorID, description, imagePath) VALUES
  ('C001', 'VoltLab Mechanics',  5000.00, 3500.00, 'Active',  'CAT_01', 'U001', 'Tearing down modern EVs to analyze battery life and quality.', 'ev_teardown.jpg'),
  ('C002', 'Honest Euro Garage', 4000.00, 4800.00, 'Active',  'CAT_02', 'U002', 'Exposing the true maintenance costs of 10-year-old luxury cars.', 'used_car.jpg'),
  ('C003', 'Trail & Tarmac',     3000.00, 1200.00, 'Active',  'CAT_03', 'U003', 'Pushing modern hybrid SUVs to their breaking point on outback trails.', 'suv.jpg'),
  ('C004', 'The MPG Truth',      3500.00, 2900.00, 'Active',  'CAT_04', 'U001', 'Cross-referencing manufacturer fuel economy with real-world data.', 'data_chart.jpg'),
  ('C005', 'JDM Tuner Labs',     6000.00,    0.00, 'Pending', 'CAT_05', 'U003', 'Exploring the world of Japanese domestic market tuning.', NULL);

INSERT INTO Tier (id, campaignID, name, price, perks) VALUES
  ('T001', 'C001', 'Bronze',    5.00,  'Early access to videos.'),
  ('T002', 'C001', 'Silver',    15.00, 'Download raw Excel diagnostic data.'),
  ('T003', 'C001', 'Gold',      30.00, 'Vote on next vehicle + Private Q&A.'),
  ('T004', 'C002', 'Supporter', 10.00, 'Access to repair receipts and invoices.'),
  ('T005', 'C004', 'Data Nerd', 20.00, 'Full OBD-II data logs and fuel charts.');

INSERT INTO Subscription (id, subscriberID, campaignID, tierID, amount, status) VALUES
  ('SUB_1', 'U002', 'C001', 'T002', 15.00, 'Active'),
  ('SUB_2', 'U003', 'C001', 'T003', 30.00, 'Active'),
  ('SUB_3', 'U002', 'C002', 'T004', 10.00, 'Active'),
  ('SUB_4', 'U005', 'C003', 'T001',  5.00, 'Cancelled'),
  ('SUB_5', 'U003', 'C004', 'T005', 20.00, 'Active');

INSERT INTO Post (id, campaignID, title, description, visibility, datePosted) VALUES
  ('P001', 'C001', 'Month 3 Coolant Leak',  'Found weeping near the high-voltage line.',   'Subscribers', '2026-09-01'),
  ('P002', 'C002', 'BMW N54 Teardown',      'Walnut blasting the intake valves.',          'Public',      '2026-09-05'),
  ('P003', 'C003', 'Suspension Failure',    'The control arm snapped at 40k miles.',       'Subscribers', '2026-09-08'),
  ('P004', 'C004', 'Highway MPG Test',      'Cross-referencing dashboard MPG vs pump.',    'Public',      '2026-09-09'),
  ('P005', 'C001', 'Battery Health Check',  'Degradation is at 4% after 50k miles.',       'Subscribers', '2026-09-10');

INSERT INTO PostAttachment (postID, fileURL, fileType) VALUES
  ('P001', '/files/coolant_leak.jpg',        'image/jpeg'),
  ('P001', '/files/repair_invoice.pdf',      'application/pdf'),
  ('P002', '/files/valves_before_after.png', 'image/png'),
  ('P004', '/files/mpg_data.csv',            'text/csv'),
  ('P005', '/files/obd2_scan_log.txt',       'text/plain');

INSERT INTO Poll (id, campaignID, question, status) VALUES
  ('PL01', 'C001', 'Which EV should we teardown next?',     'Active'),
  ('PL02', 'C002', 'Next 10-year-old luxury sedan to buy?', 'Closed'),
  ('PL03', 'C003', 'Which 4x4 for the outback test?',       'Active'),
  ('PL04', 'C004', 'Next hybrid for MPG verification?',     'Active'),
  ('PL05', 'C005', 'Which 90s JDM legend to restore?',      'Pending');

INSERT INTO VehicleCandidate (id, pollID, vehicleName, imageURL) VALUES
  ('VC01', 'PL01', 'BYD Sealion 7',          '/img/byd_sealion.jpg'),
  ('VC02', 'PL01', 'Hyundai Ioniq 5 N',      '/img/ioniq5.jpg'),
  ('VC03', 'PL01', 'Tesla Model 3 Highland', '/img/model3.jpg'),
  ('VC04', 'PL02', 'Mercedes E350 W212',     '/img/e350.jpg'),
  ('VC05', 'PL02', 'Lexus GS350',            '/img/gs350.jpg');

INSERT INTO Vote (pollID, subscriberID, candidateID, dateVoted) VALUES
  ('PL01', 'U002', 'VC01', '2026-09-05'),
  ('PL01', 'U003', 'VC02', '2026-09-06'),
  ('PL01', 'U005', 'VC01', '2026-09-06'),
  ('PL02', 'U002', 'VC04', '2026-08-20'),
  ('PL02', 'U003', 'VC05', '2026-08-21');

INSERT INTO Comment (id, campaignID, subscriberID, text, datePosted) VALUES
  ('CM01', 'C001', 'U002', 'Thanks for the raw data! Saved me from buying a lemon.',     '2026-09-02'),
  ('CM02', 'C002', 'U003', 'I knew that engine was a money pit. Great teardown.',        '2026-09-06'),
  ('CM03', 'C001', 'U005', 'This data is misleading, the brand is actually great!',      '2026-09-03'),
  ('CM04', 'C004', 'U002', 'Pump data doesn''t lie. Manufacturer claims are way off.',   '2026-09-10'),
  ('CM05', 'C003', 'U003', 'Can you test the sway bar links next? Mine keep breaking.',  '2026-09-09');

INSERT INTO Report (id, contentType, contentID, reason, reportCount, status) VALUES
  ('R001', 'Comment',  'CM03', 'Spam/Harassment from brand PR Bot',       5, 'Pending'),
  ('R002', 'Post',     'P004', 'Suspected misleading fuel data',          2, 'Dismissed'),
  ('R003', 'Comment',  'CM01', 'Inappropriate language',                  1, 'Dismissed'),
  ('R004', 'User',     'U005', 'Bot account spreading brand propaganda',  8, 'Actioned'),
  ('R005', 'Campaign', 'C005', 'Plagiarized content from another channel', 3, 'Pending');
