-- HonestDrive database schema
-- MySQL 8.x
-- Matches app/project/__init__.py config: MYSQL_PORT 3307

CREATE DATABASE IF NOT EXISTS honestdrive
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE honestdrive;

-- Drop in reverse dependency order so the script can be re-run.
DROP VIEW IF EXISTS CampaignWithCategory;
DROP VIEW IF EXISTS CampaignWithSubscriptions;
DROP VIEW IF EXISTS TierWithPerks;
DROP VIEW IF EXISTS ReportWithUser;
DROP TABLE IF EXISTS Report;
DROP TABLE IF EXISTS Comment;
DROP TABLE IF EXISTS Vote;
DROP TABLE IF EXISTS VehicleCandidate;
DROP TABLE IF EXISTS Poll;
DROP TABLE IF EXISTS PostAttachment;
DROP TABLE IF EXISTS Post;
DROP TABLE IF EXISTS Subscription;
DROP TABLE IF EXISTS TierPerks;
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
  goalDescription TEXT,
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

CREATE OR REPLACE VIEW CampaignWithCategory AS
SELECT c.*, cat.name AS categoryName
FROM Campaign AS c
JOIN Category AS cat ON cat.id = c.categoryID;

CREATE TABLE Tier (
  id         INT AUTO_INCREMENT NOT NULL,
  campaignID INT   NOT NULL,
  name       VARCHAR(50)   NOT NULL,
  price      DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tier_campaign (id, campaignID),
  FOREIGN KEY (campaignID) REFERENCES Campaign(id) ON DELETE CASCADE
);

CREATE TABLE TierPerks (
  id INT AUTO_INCREMENT NOT NULL,
  tierID INT NOT NULL,
  campaignID INT NOT NULL,
  perk TEXT NOT NULL,
  PRIMARY KEY (id),
  FOREIGN KEY (tierID, campaignID) REFERENCES Tier(id, campaignID) ON DELETE CASCADE
);

CREATE OR REPLACE VIEW TierWithPerks AS
SELECT t.id, t.campaignID, t.name, t.price,
       COALESCE((SELECT JSON_ARRAYAGG(p.perk)
                 FROM TierPerks p
                 WHERE p.tierID = t.id AND p.campaignID = t.campaignID), JSON_ARRAY()) AS perks
FROM Tier t;

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
  isHidden    BOOLEAN NOT NULL DEFAULT FALSE,
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
  reporterID  INT NOT NULL,
  dateReported DATE NOT NULL DEFAULT (CURRENT_DATE),
  PRIMARY KEY (id),
  FOREIGN KEY (reporterID) REFERENCES `User`(id)
);

CREATE OR REPLACE VIEW ReportWithUser AS
SELECT r.*, u.name AS reporterName
FROM Report AS r
JOIN `User` AS u ON u.id = r.reporterID;


-- Subscription details for each campaign; filter by campaignID when querying.
CREATE OR REPLACE VIEW CampaignWithSubscriptions AS
SELECT
    s.id AS subscriptionID,
    c.id AS campaignID,
    c.title AS campaignTitle,
    c.creatorID,
    c.goalDescription,
    s.subscriberID,
    CASE WHEN s.isAnonymous THEN 'Anonymous' ELSE u.name END AS subscriberName,
    s.tierID,
    t.name AS tierName,
    t.price AS tierPrice,
    t.perks AS tierPerks,
    s.amount,
    s.paymentMethod,
    s.message,
    s.isAnonymous,
    s.status,
    s.startDate,
    s.cancelledDate
FROM Subscription AS s
JOIN Campaign AS c ON c.id = s.campaignID
JOIN `User` AS u ON u.id = s.subscriberID
JOIN TierWithPerks AS t ON t.id = s.tierID AND t.campaignID = s.campaignID;

-- =========================================================
-- Sample data
-- =========================================================

-- Assessment test passwords: email local part, including any dots.
-- john@test.com : john
-- sarah.m@test.com : sarah.m
-- mike.r@test.com : mike.r
-- admin@test.com : admin
-- daniel@test.com : daniel
-- kobe@test.com : kobe
-- supporter@test.com : supporter
-- fundraiser@test.com : fundraiser
INSERT INTO `User` (name, email, password, role, accountStatus, channelName, bio) VALUES
  ('Jeremy Smith', 'john@test.com', 'pbkdf2:sha256:600000$KyHjf2CbO4xRrfdW$b2340aa1d71a864da034497a54f6d8ad944573fb57589b6b691a9a69b5dcf613', 'Administrator', 'Active', NULL, NULL),
  ('Sarah M.', 'sarah.m@test.com', 'pbkdf2:sha256:600000$MfXrVv0bOkHXkoX0$8e074aba2ed550524389e9356b3695e18f62c0bf93c8d36c25debf3a95086420', 'Supporter', 'Active', NULL, NULL),
  ('Mike R.', 'mike.r@test.com', 'pbkdf2:sha256:600000$8cKFAZLfphrmcBkn$c684d93c87ca0fdd5f70a57b68c257739cbc6d11cff7eeeaf115ec7129659878', 'Supporter', 'Active', NULL, NULL),
  ('Admin Root', 'admin@test.com', 'pbkdf2:sha256:600000$lIYiYd9dXf0wjoN7$4e0491601351945befbbbf12aa657128cb47f28e3926fe4489914983ca54e9c1', 'Administrator', 'Active', NULL, NULL),
  ('Daniel Lee', 'daniel@test.com', 'pbkdf2:sha256:600000$h2NzZEm0HTqGsBh5$901aa982a441564cabf014b9abb17eb6a0449cdc9a32b1f97d3fd341819d5ce7', 'Fundraiser', 'Active', 'Torque & Volts', 'Former dealership technician turned independent tester. I spend my weeks under EVs, SUVs and tuned Japanese cars, and publish every measurement so buyers can decide based on data, not marketing.'),
  ('Kobe Chen', 'kobe@test.com', 'pbkdf2:sha256:600000$JsCN3qPQ7QtXAQoe$529c5ffeec0d67d89b64709dc57959bc9f6c4d45b3494e3607bc5c62940f30cf', 'Fundraiser', 'Active', 'Real Cost Garage', 'Qualified mechanic with twelve years in European and hybrid workshops. I buy the cars people are nervous about owning, keep every receipt, and share exactly what they cost to run.'),
  ('Test Supporter', 'supporter@test.com', 'pbkdf2:sha256:600000$BWzjy24q6oTOQh5X$3406a36fef88b3f0deb4b778ad1924dc3c6d8ed8452e1b210c15dde4ad3e0547', 'Supporter', 'Suspended', NULL, NULL),
  ('Test Fundraiser', 'fundraiser@test.com', 'pbkdf2:sha256:600000$Ig3bpTT6lczM0dPr$bd8cf4bc02b390702bf200b812248953c563d0fd3f449403eba96fdd09e92265', 'Fundraiser', 'Active', NULL, NULL);

INSERT INTO Category (name, description) VALUES
  ('EV Testing',  'Long-term electric vehicle battery and motor teardowns.'),
  ('Used Cars',   'Maintenance analysis of out-of-warranty luxury vehicles.'),
  ('SUVs & 4x4',  'Off-road capability and suspension durability testing.'),
  ('Performance', 'Track day stress tests and aftermarket parts reviews.'),
  ('Economy',     'Real-world MPG and daily commuter running costs.');

INSERT INTO Campaign (title, monthlyGoal, currentRaised, approval_status, operational_status, featured, categoryID, creatorID, description, imagePath, goalDescription) VALUES
  ('VoltLab Mechanics', 5000.00, 45.00, 'Approved', 'Active', TRUE, 1, 5, 'We drive popular EVs hard for a full year, then tear them down to show exactly how the battery, motor and cooling system have aged.', 'ev_teardown.jpg', 'Our $5,000 monthly goal keeps the BYD Seal endurance test on the road. Around $2,800 covers the vehicle lease and insurance, $1,200 pays for battery health scans and independent lab testing, and $1,000 goes on replacement parts and filming. Every month we publish a test log with mileage, range and cell-balance readings, and supporters get the raw diagnostic files.'),
  ('Honest Euro Garage', 4000.00, 10.00, 'Approved', 'Active', TRUE, 2, 6, 'We own the 10-year-old BMWs, Audis and Mercedes that dealers would rather not talk about, and publish every repair invoice so you know the real cost before you buy.', 'used_car.jpg', 'Our $4,000 monthly goal keeps three ageing European cars running: a BMW 335i, an Audi A4 and a Mercedes C250, all more than ten years old. About $2,500 covers workshop labour and parts, $900 pays for specialist diagnostic tools, and $600 goes on registration and insurance. Every invoice is scanned and shared, so buyers can see the true cost of ownership year by year.'),
  ('Trail & Tarmac', 3000.00, 5.00, 'Approved', 'Active', FALSE, 3, 5, 'Same SUVs, same routes, every month. We track suspension wear on corrugated gravel, beach sand and city potholes to find out which 4x4s really hold up.', 'suv.jpg', 'Our $3,000 monthly goal covers fuel and travel for our fixed test loop of city streets, highway, gravel and sand, plus a wheel-alignment and suspension inspection after every loop. When shocks, bushings or control arms fail, your support pays for the replacements. We document each failure with photos, mileage and repair quotes so you can compare models before you buy.'),
  ('The MPG Truth', 3500.00, 20.00, 'Approved', 'Active', FALSE, 5, 6, 'The window sticker promises 50 MPG, but the fuel receipts often disagree. We log every tank in real traffic and publish the raw data, not just the headline figure.', 'data_chart.jpg', 'Our $3,500 monthly goal pays for fuel, short-term vehicle hire and OBD-II data loggers. Each car drives the same 300 km city and highway route three times, and we compare the trip computer, the pump receipts and the official rating side by side. Supporters receive the complete spreadsheets, so anyone can check our maths.'),
  ('JDM Tuner Labs', 6000.00, 5.00, 'Approved', 'Active', FALSE, 4, 5, 'From bolt-on intakes to big turbo kits, we dyno-test popular Japanese tuning upgrades and track what they really do to power, reliability and your wallet.', 'JDM.jpg', 'Our $6,000 monthly goal covers two dyno sessions, test parts and specialist workshop time. We measure power and torque before and after each upgrade, then drive the car for 5,000 km to check for heat, knock and reliability problems. Every video ends with a cost-per-horsepower breakdown, so you know which upgrades are worth the money.'),
  ('Battery Second Life', 2500.00, 0.00, 'Suspended', 'Paused', FALSE, 1, 6, 'Can a worn-out EV battery still power a home or workshop? We measure the capacity left in retired packs and test whether they are safe to reuse.', 'ev_teardown.jpg', 'Support capacity measurements and safety inspections of used EV batteries to assess their potential for reuse.'),
  ('Budget Hatchback Lab', 1500.00, 0.00, 'Suspended', 'Closed', FALSE, 5, 5, 'Yaris, Mazda2, Swift or i20? We run budget hatchbacks side by side for a year and add up fuel, servicing and tyres to find the cheapest daily driver.', 'data_chart.jpg', 'Help fund fuel, servicing and diagnostic checks for practical comparisons of budget hatchback running costs.'),
  ('Outback Suspension', 3200.00, 0.00, 'Rejected', 'Closed', FALSE, 3, 6, 'Corrugated dirt roads destroy suspension. We drive the same outback routes every season and measure how shocks, bushings and springs wear out.', 'suv.jpg', 'Help cover rough-road test trips, suspension inspections and replacement components to document long-term wear.'),
  ('Used Hybrid Check', 2200.00, 0.00, 'Pending', 'Closed', FALSE, 2, 5, 'Is a 10-year-old Prius a bargain or a battery bill waiting to happen? We inspect ageing hybrids and price every repair they need.', 'used_car.jpg', 'Fund battery diagnostics and drivetrain inspections that help buyers understand the condition of used hybrids.'),
  ('Track Brake Testing', 4200.00, 0.00, 'Rejected', 'Closed', FALSE, 4, 6, 'Repeatable brake fade tests on track. We compare pads, fluids and rotors lap after lap and publish the temperature and stopping-distance data.', 'data_chart.jpg', 'Support track access, brake components and measuring equipment for repeatable brake fade and wear tests.'),
  ('Charging Efficiency', 2800.00, 0.00, 'Suspended', 'Paused',FALSE, 1, 5, 'Not every kWh you pay for reaches the battery. We meter home, AC and DC fast charging to show how much energy is lost and what it costs you.', 'ev_teardown.jpg', 'Fund access to different chargers and energy meters to compare charging losses under real-world conditions.'),
  ('Luxury Sedan MPG', 3500.00, 0.00, 'Pending', 'Paused', FALSE, 2, 6, 'Do big luxury sedans really sip fuel the way the brochure says? We test used 5 Series, E-Class and Lexus GS models in city and highway driving.', 'data_chart.jpg', 'Help cover fuel and data collection for city and highway economy tests of used luxury sedans.'),
  ('Off-Road Durability', 3000.00, 0.00, 'Rejected', 'Closed', FALSE, 3, 5, 'We take everyday 4x4s well off the beaten track and record what breaks first, from CV joints to skid plates, with full repair costs.', 'suv.jpg', 'Support off-road test trips and component inspections to document vehicle durability and repair needs.'),
  ('EV Battery Health', 5000.00, 0.00, 'Suspended', 'Paused', FALSE, 1, 5, 'We test the same EVs every three months to chart battery degradation, showing how real-world range changes as the cars age.', 'ev_teardown.jpg', 'Fund battery diagnostics and repeated capacity measurements to track degradation as vehicles age.'),
  ('Hybrid Drivetrain Check', 2200.00, 0.00, 'Rejected', 'Closed', FALSE, 2, 6, 'A deep dive into ageing hybrid transmissions, inverters and cooling systems, backed by specialist inspections and real repair quotes.', 'used_car.jpg', 'Support specialist inspections and diagnostic testing to explain ageing hybrid drivetrain maintenance costs.');

INSERT INTO Tier (campaignID, name, price) VALUES
  (1, 'Bronze', 5),
  (1, 'Silver', 15),
  (1, 'Gold', 30),
  (2, 'Supporter', 10),
  (4, 'Data Nerd', 20),
  (3, 'Trail Supporter', 5),
  (5, 'Supporter', 5),
  (6, 'Supporter', 5),
  (7, 'Supporter', 5),
  (8, 'Supporter', 5),
  (9, 'Supporter', 5),
  (10, 'Supporter', 5),
  (11, 'Supporter', 5),
  (12, 'Supporter', 5),
  (13, 'Supporter', 5),
  (14, 'Supporter', 5),
  (15, 'Supporter', 5),
  (2, 'Garage Regular', 25),
  (3, 'Off-Road Crew', 15),
  (4, 'Commuter', 5),
  (5, 'Pit Crew', 15),
  (5, 'Race Team', 35);

INSERT INTO TierPerks (tierID, campaignID, perk) VALUES
  (1, 1, 'Early access to videos.'),
  (2, 1, 'Download raw Excel diagnostic data.'),
  (3, 1, 'Vote on next vehicle.'),
  (3, 1, 'Private Q&A.'),
  (4, 2, 'Access to repair receipts and invoices.'),
  (5, 4, 'Full OBD-II data logs and fuel charts.'),
  (6, 3, 'Monthly suspension testing updates.'),
  (7, 5, 'Early access to every dyno video.'),
  (8, 6, 'Monthly testing updates.'),
  (9, 7, 'Monthly testing updates.'),
  (10, 8, 'Monthly testing updates.'),
  (11, 9, 'Monthly testing updates.'),
  (12, 10, 'Monthly testing updates.'),
  (13, 11, 'Monthly testing updates.'),
  (14, 12, 'Monthly testing updates.'),
  (15, 13, 'Monthly testing updates.'),
  (16, 14, 'Monthly testing updates.'),
  (17, 15, 'Monthly testing updates.'),
  (18, 2, 'Monthly cost-of-ownership spreadsheet for every car.'),
  (18, 2, 'Vote on the next car we buy.'),
  (19, 3, 'Full inspection photos and wear measurements.'),
  (19, 3, 'Suggest a route for our next test loop.'),
  (20, 4, 'Monthly results summary and fuel economy league table.'),
  (21, 5, 'Raw dyno charts from every session.'),
  (21, 5, 'Vote on the next upgrade we test.'),
  (22, 5, 'Monthly live Q&A with our tuner.'),
  (22, 5, 'Your name on the test car.');

-- currentRaised is the sum of active monthly support in this subscription scenario.
INSERT INTO Subscription (subscriberID, campaignID, tierID, amount, paymentMethod, message, status, startDate) VALUES
  (2, 1, 2, 15.00, 'Simulated card', 'Please keep sharing battery measurements.', 'Active', '2026-09-01'),
  (3, 1, 3, 30.00, 'Simulated card', 'Looking forward to the next teardown.', 'Active', '2026-09-02'),
  (2, 2, 4, 10.00, 'Simulated bank transfer', 'The repair cost breakdowns are helpful.', 'Active', '2026-09-03'),
  (3, 3, 6, 5.00, 'Simulated card', 'More suspension testing please.', 'Active', '2026-09-04'),
  (3, 4, 5, 20.00, 'Simulated bank transfer', 'Thanks for publishing the raw fuel data.', 'Active', '2026-09-05'),
  (2, 5, 7, 5.00, 'Simulated card', 'Excited to learn about performance tuning.', 'Active', '2026-09-06');

INSERT INTO Post (campaignID, title, description, visibility, datePosted) VALUES
  (1, 'Month 3 Coolant Leak',  'Found weeping near the high-voltage line.',   'Subscribers', '2026-09-01'),
  (2, 'BMW N54 Teardown',      'Walnut blasting the intake valves.',          'Public',      '2026-09-05'),
  (3, 'Suspension Failure',    'The control arm snapped at 40k miles.',       'Subscribers', '2026-09-08'),
  (3, 'Suspension test',       'The control arm snapped at 400000k miles.',    'Public',     '2026-09-08'),
  (4, 'Highway MPG Test',      'Cross-referencing dashboard MPG vs pump.',    'Public',      '2026-09-09'),
  (5, 'Turbo Boost Leak Test', 'Found a cracked intercooler pipe at 18 psi.', 'Subscribers', '2026-09-10');

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

INSERT INTO Comment (campaignID, subscriberID, text, datePosted) VALUES
  (1, 2, 'Thanks for the raw data! Saved me from buying a lemon.',     '2026-09-02'),
  (2, 3, 'I knew that engine was a money pit. Great teardown.',        '2026-09-06'),
  (1, 3, 'This data is misleading, the brand is actually great!',      '2026-09-03'),
  (4, 2, 'Pump data doesn''t lie. Manufacturer claims are way off.',   '2026-09-10'),
  (3, 3, 'Can you test the sway bar links next? Mine keep breaking.',  '2026-09-09');

-- Sample reporter identities and dates for demonstration.
INSERT INTO Report (contentType, contentID, reason, reportCount, status, reporterID, dateReported) VALUES
  ('Comment',  3, 'Suspected misleading promotional comment', 5, 'Pending', 2, '2026-09-11'),
  ('Post',     4, 'Suspected misleading fuel data',          2, 'Dismissed', 3, '2026-09-12'),
  ('Comment',  1, 'Inappropriate language',                  1, 'Dismissed', 3, '2026-09-13'),
  ('User',     8, 'Bot account spreading brand propaganda',  8, 'Actioned', 2, '2026-09-14'),
  ('Campaign', 5, 'Plagiarized content from another channel', 3, 'Pending', 3, '2026-09-15'),
  ('Post', 5, 'Fuel economy results appear inconsistent with the published measurements.', 1, 'Pending', 2, '2026-10-16'),
  ('User', 8, 'Suspected repeated unsolicited promotional messages.', 1, 'Pending', 3, '2026-10-16');
