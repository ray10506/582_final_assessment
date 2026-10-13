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
-- Application checks remain required: authenticated role, campaign ownership,
-- and allowed status transitions. Fundraisers must never change Pending,
-- Rejected or Suspended campaigns to Active without administrator approval.
-- Report targets are polymorphic: validate contentType/contentID together
-- in the application on create/update and when removing reported content.
-- =========================================================

CREATE TABLE `User` (
  id             INT AUTO_INCREMENT NOT NULL,
  name           VARCHAR(100) NOT NULL,
  email          VARCHAR(255) NOT NULL,
  password       VARCHAR(255) NOT NULL,
  role           VARCHAR(20)  NOT NULL,
  channelName    VARCHAR(100),
  bio            TEXT,
  bannerImageURL VARCHAR(255),
  accountStatus  VARCHAR(20)  NOT NULL DEFAULT 'Active', -- Active | Suspended 
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_email (email)
);

CREATE TABLE Category (
  id          INT AUTO_INCREMENT NOT NULL,
  name        VARCHAR(100) NOT NULL,
  description TEXT,
  PRIMARY KEY (id)
);

CREATE TABLE Campaign (
  id            INT AUTO_INCREMENT NOT NULL,
  title         VARCHAR(150)  NOT NULL,
  description   TEXT,
  monthlyGoal   DECIMAL(10,2) NOT NULL,
  currentRaised DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  approval_status        VARCHAR(20)   NOT NULL DEFAULT 'Pending',  -- Pending | Approved | Rejected | Suspended
  operational_status     VARCHAR(20)   NOT NULL DEFAULT 'Active',   -- Active | Paused | Closed
  featured      BOOLEAN       NOT NULL DEFAULT FALSE,
  categoryID    INT   NOT NULL,
  creatorID     INT   NOT NULL,
  imagePath     VARCHAR(255),
  PRIMARY KEY (id),
  FOREIGN KEY (categoryID) REFERENCES Category(id),
  FOREIGN KEY (creatorID)  REFERENCES `User`(id)
);

CREATE TABLE Tier (
  id         INT AUTO_INCREMENT NOT NULL,
  campaignID INT   NOT NULL,
  name       VARCHAR(50)   NOT NULL,
  price      DECIMAL(10,2) NOT NULL,
  perks      TEXT,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tier_campaign (id, campaignID),
  FOREIGN KEY (campaignID) REFERENCES Campaign(id) ON DELETE CASCADE
);

CREATE TABLE Subscription (
  id            INT AUTO_INCREMENT NOT NULL,
  subscriberID  INT   NOT NULL,
  campaignID    INT   NOT NULL,
  tierID        INT   NOT NULL,
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
  FOREIGN KEY (tierID, campaignID) REFERENCES Tier(id, campaignID)
);

CREATE TABLE Post (
  id          INT AUTO_INCREMENT NOT NULL,
  campaignID  INT   NOT NULL,
  title       VARCHAR(150) NOT NULL,
  description TEXT,
  visibility  VARCHAR(20)  NOT NULL DEFAULT 'Public',
  datePosted  DATE         NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (campaignID) REFERENCES Campaign(id) ON DELETE CASCADE
);

-- Composite PK: one row per file attached to a post (1NF).
CREATE TABLE PostAttachment (
  postID   INT  NOT NULL,
  fileURL  VARCHAR(255) NOT NULL,
  fileType VARCHAR(100) NOT NULL,
  PRIMARY KEY (postID, fileURL),
  FOREIGN KEY (postID) REFERENCES Post(id) ON DELETE CASCADE
);

CREATE TABLE Poll (
  id         INT  NOT NULL,
  campaignID INT  NOT NULL,
  question   VARCHAR(255) NOT NULL,
  status     VARCHAR(20)  NOT NULL DEFAULT 'Pending',
  PRIMARY KEY (id),
  FOREIGN KEY (campaignID) REFERENCES Campaign(id) ON DELETE CASCADE
);

CREATE TABLE VehicleCandidate (
  id          INT  NOT NULL,
  pollID      INT  NOT NULL,
  vehicleName VARCHAR(150) NOT NULL,
  imageURL    VARCHAR(255),
  PRIMARY KEY (id),
  UNIQUE KEY uq_candidate_poll (id, pollID),
  FOREIGN KEY (pollID) REFERENCES Poll(id) ON DELETE CASCADE
);

-- Composite PK (pollID, subscriberID): one vote per subscriber per poll.
-- The (candidateID, pollID) FK guarantees the chosen candidate belongs to that poll.
CREATE TABLE Vote (
  pollID       INT NOT NULL,
  subscriberID INT NOT NULL,
  candidateID  INT NOT NULL,
  dateVoted    DATE        NOT NULL,
  PRIMARY KEY (pollID, subscriberID),
  FOREIGN KEY (pollID)       REFERENCES Poll(id) ON DELETE CASCADE,
  FOREIGN KEY (subscriberID) REFERENCES `User`(id),
  FOREIGN KEY (candidateID, pollID) REFERENCES VehicleCandidate(id, pollID)
);

CREATE TABLE Comment (
  id           INT AUTO_INCREMENT NOT NULL,
  campaignID   INT NOT NULL,
  subscriberID INT NOT NULL,
  text         TEXT        NOT NULL,
  datePosted   DATE        NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (campaignID)   REFERENCES Campaign(id) ON DELETE CASCADE,
  FOREIGN KEY (subscriberID) REFERENCES `User`(id)
);

-- contentID points at a Comment, Post, User or Campaign depending on contentType,
-- so it cannot carry a single foreign key.
CREATE TABLE Report (
  id          INT AUTO_INCREMENT NOT NULL,
  contentType VARCHAR(20)  NOT NULL,
  contentID   INT  NOT NULL,
  reason      VARCHAR(255) NOT NULL,
  reportCount INT          NOT NULL DEFAULT 1,
  status      VARCHAR(20)  NOT NULL DEFAULT 'Pending',
  PRIMARY KEY (id)
);

-- =========================================================
-- Sample data
-- =========================================================

-- Assessment test passwords: email local part, including any dots.
-- john@test.com : john
-- sarah.m@test.com : sarah.m
-- mike.r@test.com : mike.r
-- admin@test.com : admin
-- spam@test.com : spam
-- kobe@test.com : kobe
-- supporter@test.com : supporter
-- fundraiser@test.com : fundraiser
INSERT INTO `User` (id, name, email, password, role, accountStatus) VALUES
  (1, 'Jeremy Smith', 'john@test.com', 'pbkdf2:sha256:600000$KyHjf2CbO4xRrfdW$b2340aa1d71a864da034497a54f6d8ad944573fb57589b6b691a9a69b5dcf613', 'Administrator', 'Active'),
  (2, 'Sarah M.', 'sarah.m@test.com', 'pbkdf2:sha256:600000$MfXrVv0bOkHXkoX0$8e074aba2ed550524389e9356b3695e18f62c0bf93c8d36c25debf3a95086420', 'Supporter', 'Active'),
  (3, 'Mike R.', 'mike.r@test.com', 'pbkdf2:sha256:600000$8cKFAZLfphrmcBkn$c684d93c87ca0fdd5f70a57b68c257739cbc6d11cff7eeeaf115ec7129659878', 'Supporter', 'Active'),
  (4, 'Admin Root', 'admin@test.com', 'pbkdf2:sha256:600000$lIYiYd9dXf0wjoN7$4e0491601351945befbbbf12aa657128cb47f28e3926fe4489914983ca54e9c1', 'Administrator', 'Active'),
  (5, 'PR Bot', 'spam@test.com', 'pbkdf2:sha256:600000$LjLYCvHYJHUft5xF$6dcfd14495de894c439664eff76ed9ea73e79d79a9f654d66a68505fcfba6d94', 'Fundraiser', 'Active'),
  (6, 'Kobe Bryant', 'kobe@test.com', 'pbkdf2:sha256:600000$JsCN3qPQ7QtXAQoe$529c5ffeec0d67d89b64709dc57959bc9f6c4d45b3494e3607bc5c62940f30cf', 'Fundraiser', 'Active'),
  (7, 'Test Supporter', 'supporter@test.com', 'pbkdf2:sha256:600000$BWzjy24q6oTOQh5X$3406a36fef88b3f0deb4b778ad1924dc3c6d8ed8452e1b210c15dde4ad3e0547', 'Supporter', 'Suspended'),
  (8, 'Test Fundraiser', 'fundraiser@test.com', 'pbkdf2:sha256:600000$Ig3bpTT6lczM0dPr$bd8cf4bc02b390702bf200b812248953c563d0fd3f449403eba96fdd09e92265', 'Fundraiser', 'Active');

INSERT INTO Category (id, name, description) VALUES
  (1, 'EV Testing',  'Long-term electric vehicle battery and motor teardowns.'),
  (2, 'Used Cars',   'Maintenance analysis of out-of-warranty luxury vehicles.'),
  (3, 'SUVs & 4x4',  'Off-road capability and suspension durability testing.'),
  (4, 'Performance', 'Track day stress tests and aftermarket parts reviews.'),
  (5, 'Economy',     'Real-world MPG and daily commuter running costs.');

INSERT INTO Campaign (id, title, monthlyGoal, currentRaised, approval_status, operational_status, featured, categoryID, creatorID, description, imagePath) VALUES
  (1, 'VoltLab Mechanics', 5000.00, 45.00, 'Approved', 'Active', TRUE, 1, 5, 'Tearing down modern EVs to analyze battery life and quality.', 'ev_teardown.jpg'),
  (2, 'Honest Euro Garage', 4000.00, 10.00, 'Approved', 'Active', TRUE, 2, 6, 'Exposing the true maintenance costs of 10-year-old luxury cars.', 'used_car.jpg'),
  (3, 'Trail & Tarmac', 3000.00, 5.00, 'Approved', 'Active', FALSE, 3, 5, 'Testing SUV suspension and off-road durability.', 'suv.jpg'),
  (4, 'The MPG Truth', 3500.00, 20.00, 'Approved', 'Active', FALSE, 5, 6, 'Comparing advertised fuel economy with real-world data.', 'data_chart.jpg'),
  (5, 'JDM Tuner Labs', 6000.00, 0.00, 'Approved', 'Active', FALSE, 4, 5, 'Exploring Japanese performance tuning.', 'used_car.jpg'),
  (6, 'Battery Second Life', 2500.00, 5.00, 'Suspended', 'Paused', FALSE, 1, 6, 'Measuring the remaining capacity of used EV batteries.', 'ev_teardown.jpg'),
  (7, 'Budget Hatchback Lab', 1500.00, 0.00, 'Suspended', 'Closed', FALSE, 5, 5, 'Comparing affordable daily commuter running costs.', 'data_chart.jpg'),
  (8, 'Outback Suspension', 3200.00, 0.00, 'Rejected', 'Closed', FALSE, 3, 6, 'Documenting suspension wear on rough Australian roads.', 'suv.jpg'),
  (9, 'Used Hybrid Check', 2200.00, 0.00, 'Pending', 'Closed', FALSE, 2, 5, 'Inspecting ageing hybrid drivetrains and repair costs.', 'used_car.jpg'),
  (10, 'Track Brake Testing', 4200.00, 0.00, 'Rejected', 'Closed', FALSE, 4, 6, 'Publishing repeatable brake fade and wear measurements.', 'data_chart.jpg'),
  (11, 'Charging Efficiency', 2800.00, 0.00, 'Suspended', 'Paused',FALSE, 1, 5, 'Measuring real-world charging efficiency of EVs.', 'ev_teardown.jpg'),
  (12, 'Luxury Sedan MPG', 3500.00, 0.00, 'Pending', 'Paused', FALSE, 2, 6, 'Comparing advertised vs actual fuel economy of luxury sedans.', 'data_chart.jpg'),
  (13, 'Off-Road Durability', 3000.00, 0.00, 'Rejected', 'Closed', FALSE, 3, 5, 'Testing off-road durability of SUVs and 4x4s.', 'suv.jpg'),
  (14, 'EV Battery Health', 5000.00, 0.00, 'Suspended', 'Paused', FALSE, 1, 5, 'Analyzing long-term battery health in electric vehicles.', 'ev_teardown.jpg'),
  (15, 'Hybrid Drivetrain Check', 2200.00, 0.00, 'Rejected', 'Closed', FALSE, 2, 6, 'Inspecting ageing hybrid drivetrains and repair costs.', 'used_car.jpg');

INSERT INTO Tier (id, campaignID, name, price, perks) VALUES
  (1, 1, 'Bronze', 5.00, 'Early access to videos.'),
  (2, 1, 'Silver', 15.00, 'Download raw Excel diagnostic data.'),
  (3, 1, 'Gold', 30.00, 'Vote on next vehicle and private Q&A.'),
  (4, 2, 'Supporter', 10.00, 'Access to repair receipts and invoices.'),
  (5, 4, 'Data Nerd', 20.00, 'Full OBD-II data logs and fuel charts.'),
  (6, 3, 'Trail Supporter', 5.00, 'Monthly suspension testing updates.'),
  (8, 5, 'Supporter', 5.00, 'Monthly testing updates.'),
  (9, 6, 'Supporter', 5.00, 'Monthly testing updates.'),
  (10, 7, 'Supporter', 5.00, 'Monthly testing updates.'),
  (11, 8, 'Supporter', 5.00, 'Monthly testing updates.'),
  (12, 9, 'Supporter', 5.00, 'Monthly testing updates.'),
  (13, 10, 'Supporter', 5.00, 'Monthly testing updates.'),
  (14, 11, 'Supporter', 5.00, 'Monthly testing updates.'),
  (15, 12, 'Supporter', 5.00, 'Monthly testing updates.'),
  (16, 13, 'Supporter', 5.00, 'Monthly testing updates.'),
  (17, 14, 'Supporter', 5.00, 'Monthly testing updates.'),
  (18, 15, 'Supporter', 5.00, 'Monthly testing updates.');

-- currentRaised is the sum of active monthly support in this subscription scenario.
INSERT INTO Subscription (id, subscriberID, campaignID, tierID, amount, paymentMethod, message, status, startDate) VALUES
  (1, 2, 1, 2, 15.00, 'Simulated card', 'Please keep sharing battery measurements.', 'Active', '2026-09-01'),
  (2, 3, 1, 3, 30.00, 'Simulated card', 'Looking forward to the next teardown.', 'Active', '2026-09-02'),
  (3, 2, 2, 4, 10.00, 'Simulated bank transfer', 'The repair cost breakdowns are helpful.', 'Active', '2026-09-03'),
  (4, 3, 3, 6, 5.00, 'Simulated card', 'More suspension testing please.', 'Active', '2026-09-04'),
  (5, 3, 4, 5, 20.00, 'Simulated bank transfer', 'Thanks for publishing the raw fuel data.', 'Active', '2026-09-05'),
  (6, 2, 6, 9, 5.00, 'Simulated card', 'Excited to learn about second-life batteries.', 'Active', '2026-09-06');

INSERT INTO Post (id, campaignID, title, description, visibility, datePosted) VALUES
  (1, 1, 'Month 3 Coolant Leak',  'Found weeping near the high-voltage line.',   'Subscribers', '2026-09-01'),
  (2, 2, 'BMW N54 Teardown',      'Walnut blasting the intake valves.',          'Public',      '2026-09-05'),
  (3, 3, 'Suspension Failure',    'The control arm snapped at 40k miles.',       'Subscribers', '2026-09-08'),
  (4, 4, 'Highway MPG Test',      'Cross-referencing dashboard MPG vs pump.',    'Public',      '2026-09-09'),
  (5, 1, 'Battery Health Check',  'Degradation is at 4% after 50k miles.',       'Subscribers', '2026-09-10');

INSERT INTO PostAttachment (postID, fileURL, fileType) VALUES
  (1, '/files/coolant_leak.jpg',        'image/jpeg'),
  (1, '/files/repair_invoice.pdf',      'application/pdf'),
  (2, '/files/valves_before_after.png', 'image/png'),
  (4, '/files/mpg_data.csv',            'text/csv'),
  (5, '/files/obd2_scan_log.txt',       'text/plain');

INSERT INTO Poll (id, campaignID, question, status) VALUES
  (1, 1, 'Which EV should we teardown next?',     'Active'),
  (2, 2, 'Next 10-year-old luxury sedan to buy?', 'Closed'),
  (3, 3, 'Which 4x4 for the outback test?',       'Active'),
  (4, 4, 'Next hybrid for MPG verification?',     'Active'),
  (5, 5, 'Which 90s JDM legend to restore?',      'Pending');

INSERT INTO VehicleCandidate (id, pollID, vehicleName, imageURL) VALUES
  (1, 1, 'BYD Sealion 7',          '/img/byd_sealion.jpg'),
  (2, 1, 'Hyundai Ioniq 5 N',      '/img/ioniq5.jpg'),
  (3, 1, 'Tesla Model 3 Highland', '/img/model3.jpg'),
  (4, 2, 'Mercedes E350 W212',     '/img/e350.jpg'),
  (5, 2, 'Lexus GS350',            '/img/gs350.jpg');

INSERT INTO Vote (pollID, subscriberID, candidateID, dateVoted) VALUES
  (1, 2, 1, '2026-09-05'),
  (1, 3, 2, '2026-09-06'),
  (2, 2, 4, '2026-08-20'),
  (2, 3, 5, '2026-08-21');

INSERT INTO Comment (id, campaignID, subscriberID, text, datePosted) VALUES
  (1, 1, 2, 'Thanks for the raw data! Saved me from buying a lemon.',     '2026-09-02'),
  (2, 2, 3, 'I knew that engine was a money pit. Great teardown.',        '2026-09-06'),
  (3, 1, 3, 'This data is misleading, the brand is actually great!',      '2026-09-03'),
  (4, 4, 2, 'Pump data doesn''t lie. Manufacturer claims are way off.',   '2026-09-10'),
  (5, 3, 3, 'Can you test the sway bar links next? Mine keep breaking.',  '2026-09-09');

INSERT INTO Report (id, contentType, contentID, reason, reportCount, status) VALUES
  (1, 'Comment',  3, 'Suspected misleading promotional comment', 5, 'Pending'),
  (2, 'Post',     4, 'Suspected misleading fuel data',          2, 'Dismissed'),
  (3, 'Comment',  1, 'Inappropriate language',                  1, 'Dismissed'),
  (4, 'User',     5, 'Bot account spreading brand propaganda',  8, 'Actioned'),
  (5, 'Campaign', 5, 'Plagiarized content from another channel', 3, 'Pending');
