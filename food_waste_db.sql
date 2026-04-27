-- ============================================================
-- Food Waste Management System
-- Course: UCS310 - Database Management Systems
-- B.Tech 2nd Year
-- ============================================================

-- ============================================================
-- SECTION 1: DATABASE SETUP
-- ============================================================

DROP DATABASE IF EXISTS food_waste_db;
CREATE DATABASE food_waste_db;
USE food_waste_db;


-- ============================================================
-- SECTION 2: DDL - TABLE CREATION (CREATE)
-- ============================================================

-- Table 1: users
-- Stores both restaurant and NGO accounts.
-- restaurant_name moved here from food_donations to satisfy 3NF:
--   food_donations.user_id -> users.restaurant_name was a transitive dependency.
CREATE TABLE users (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    username       VARCHAR(100)            UNIQUE NOT NULL,
    password       VARCHAR(255)            NOT NULL,
    role           ENUM('restaurant','ngo') NOT NULL,
    restaurant_name VARCHAR(100)           DEFAULT NULL,
    contact_phone  VARCHAR(15)             DEFAULT NULL,
    is_active      TINYINT(1)              DEFAULT 1,
    created_at     TIMESTAMP               DEFAULT CURRENT_TIMESTAMP
);

-- Table 2: food_donations
-- restaurant_name removed (now derived via JOIN with users).
CREATE TABLE food_donations (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT                            NOT NULL,
    food_type     VARCHAR(100)                   NOT NULL,
    quantity      INT                            NOT NULL,
    expiry_time   DATETIME                       NOT NULL,
    status        ENUM('Available','Claimed','Expired') DEFAULT 'Available',
    pickup_notes  TEXT                           DEFAULT NULL,
    created_at    TIMESTAMP                      DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_donation_user  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_quantity      CHECK (quantity > 0)
);

-- Table 3: donation_claims
-- Tracks which NGO claimed which donation and when.
CREATE TABLE donation_claims (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    donation_id INT NOT NULL,
    ngo_user_id INT NOT NULL,
    claimed_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_claim_donation FOREIGN KEY (donation_id) REFERENCES food_donations(id) ON DELETE CASCADE,
    CONSTRAINT fk_claim_ngo      FOREIGN KEY (ngo_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT uq_one_claim      UNIQUE (donation_id)
);

-- Table 4: audit_log
-- Records status changes and key events for accountability.
CREATE TABLE audit_log (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    action       VARCHAR(50)  NOT NULL,
    table_name   VARCHAR(50)  NOT NULL,
    record_id    INT          DEFAULT NULL,
    old_value    VARCHAR(255) DEFAULT NULL,
    new_value    VARCHAR(255) DEFAULT NULL,
    performed_by INT          DEFAULT NULL,
    action_time  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- SECTION 3: DDL - ALTER TABLE
-- ============================================================

-- Add a pickup_location column to food_donations
ALTER TABLE food_donations
    ADD COLUMN pickup_location VARCHAR(255) DEFAULT NULL AFTER pickup_notes;

-- Add an email column to users
ALTER TABLE users
    ADD COLUMN email VARCHAR(150) DEFAULT NULL AFTER contact_phone;

-- Rename email to contact_email for clarity
ALTER TABLE users
    RENAME COLUMN email TO contact_email;


-- ============================================================
-- SECTION 4: DML - INSERT (Sample Data)
-- ============================================================

-- Note: passwords below are bcrypt hashes of 'password123' (10 rounds).
-- Replace with actual bcrypt-generated hashes in production.
INSERT INTO users (username, password, role, restaurant_name, contact_phone) VALUES
('pizza_palace',    '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LPVSAs9gBTK', 'restaurant', 'Pizza Palace',            '9876543210'),
('green_bites',     '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LPVSAs9gBTK', 'restaurant', 'Green Bites Cafe',        '9876543211'),
('spice_garden',    '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LPVSAs9gBTK', 'restaurant', 'Spice Garden Restaurant', '9876543212'),
('helping_hands',   '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LPVSAs9gBTK', 'ngo',        NULL,                      '9876543213'),
('food_for_all',    '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LPVSAs9gBTK', 'ngo',        NULL,                      '9876543214');

INSERT INTO food_donations (user_id, food_type, quantity, expiry_time, status, pickup_notes) VALUES
(1, 'Vegetable Biryani', 50, DATE_ADD(NOW(), INTERVAL 4 HOUR),  'Available', 'Packed in boxes'),
(1, 'Bread and Butter',  30, DATE_ADD(NOW(), INTERVAL 2 HOUR),  'Available', 'Individually wrapped'),
(2, 'Mixed Salad',       20, DATE_ADD(NOW(), INTERVAL 6 HOUR),  'Available', 'Ready to serve'),
(2, 'Fruit Juice',       40, DATE_ADD(NOW(), INTERVAL -2 HOUR), 'Expired',   'Bottles sealed'),
(3, 'Dal and Rice',      60, DATE_ADD(NOW(), INTERVAL 5 HOUR),  'Available', 'In bulk containers'),
(3, 'Roti and Sabzi',    45, DATE_ADD(NOW(), INTERVAL 3 HOUR),  'Claimed',   'Wrapped in foil');

INSERT INTO donation_claims (donation_id, ngo_user_id) VALUES (6, 4);


-- ============================================================
-- SECTION 5: DML - UPDATE
-- ============================================================

-- Auto-expire donations whose time has passed
UPDATE food_donations
SET status = 'Expired'
WHERE expiry_time < NOW()
  AND status = 'Available';


-- ============================================================
-- SECTION 6: DML - DELETE
-- ============================================================

-- Remove expired donations older than 7 days to keep the table clean
DELETE FROM food_donations
WHERE status = 'Expired'
  AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY);


-- ============================================================
-- SECTION 7: ADVANCED SELECT QUERIES
-- ============================================================

-- 7.1 INNER JOIN: Available donations with their restaurant names
SELECT
    fd.id,
    u.restaurant_name,
    u.contact_phone  AS restaurant_contact,
    fd.food_type,
    fd.quantity,
    fd.expiry_time,
    fd.status
FROM food_donations fd
INNER JOIN users u ON fd.user_id = u.id
WHERE fd.status = 'Available'
ORDER BY fd.expiry_time ASC;

-- 7.2 Multi-table JOIN: Claimed donations showing NGO that claimed them
SELECT
    fd.id            AS donation_id,
    u_rest.restaurant_name,
    fd.food_type,
    fd.quantity,
    u_ngo.username   AS claimed_by_ngo,
    dc.claimed_at
FROM food_donations fd
INNER JOIN users         u_rest ON fd.user_id       = u_rest.id
INNER JOIN donation_claims dc   ON fd.id            = dc.donation_id
INNER JOIN users         u_ngo  ON dc.ngo_user_id   = u_ngo.id;

-- 7.3 LEFT JOIN: All restaurants with donation count (including those with 0 donations)
SELECT
    u.restaurant_name,
    COUNT(fd.id) AS total_donations
FROM users u
LEFT JOIN food_donations fd ON u.id = fd.user_id
WHERE u.role = 'restaurant'
GROUP BY u.id, u.restaurant_name;

-- 7.4 Aggregate functions: Donation stats per restaurant
SELECT
    u.restaurant_name,
    COUNT(fd.id)    AS total_donations,
    SUM(fd.quantity) AS total_quantity,
    AVG(fd.quantity) AS avg_quantity,
    MAX(fd.quantity) AS max_quantity,
    MIN(fd.quantity) AS min_quantity
FROM users u
INNER JOIN food_donations fd ON u.id = fd.user_id
WHERE u.role = 'restaurant'
GROUP BY u.id, u.restaurant_name;

-- 7.5 GROUP BY + HAVING: Restaurants with more than 1 donation
SELECT
    u.restaurant_name,
    COUNT(fd.id) AS total_donations,
    SUM(fd.quantity) AS total_quantity
FROM users u
INNER JOIN food_donations fd ON u.id = fd.user_id
GROUP BY u.id, u.restaurant_name
HAVING COUNT(fd.id) > 1
ORDER BY total_donations DESC;

-- 7.6 Subquery: Restaurants with above-average donation count
SELECT username, restaurant_name
FROM users
WHERE id IN (
    SELECT user_id
    FROM food_donations
    GROUP BY user_id
    HAVING COUNT(*) > (
        SELECT AVG(cnt)
        FROM (
            SELECT COUNT(*) AS cnt
            FROM food_donations
            GROUP BY user_id
        ) AS avg_table
    )
);

-- 7.7 Subquery with EXISTS: NGOs that have claimed at least one donation
SELECT username
FROM users
WHERE role = 'ngo'
  AND EXISTS (
      SELECT 1
      FROM donation_claims
      WHERE ngo_user_id = users.id
  );

-- 7.8 Correlated subquery: Donations with quantity above their restaurant's average
SELECT fd.id, fd.food_type, fd.quantity, u.restaurant_name
FROM food_donations fd
INNER JOIN users u ON fd.user_id = u.id
WHERE fd.quantity > (
    SELECT AVG(fd2.quantity)
    FROM food_donations fd2
    WHERE fd2.user_id = fd.user_id
);


-- ============================================================
-- SECTION 8: VIEWS
-- ============================================================

-- View 1: Available donations with restaurant info (replaces plain SELECT * in app)
CREATE VIEW available_donations_view AS
SELECT
    fd.id,
    u.restaurant_name,
    u.contact_phone  AS restaurant_contact,
    fd.food_type,
    fd.quantity,
    fd.expiry_time,
    fd.pickup_notes,
    fd.pickup_location,
    fd.created_at
FROM food_donations fd
INNER JOIN users u ON fd.user_id = u.id
WHERE fd.status = 'Available'
  AND fd.expiry_time > NOW();

-- View 2: Per-restaurant donation statistics
CREATE VIEW restaurant_donation_stats AS
SELECT
    u.id              AS restaurant_id,
    u.restaurant_name,
    COUNT(fd.id)                                                AS total_donations,
    SUM(CASE WHEN fd.status = 'Available' THEN 1 ELSE 0 END)   AS available_count,
    SUM(CASE WHEN fd.status = 'Claimed'   THEN 1 ELSE 0 END)   AS claimed_count,
    SUM(CASE WHEN fd.status = 'Expired'   THEN 1 ELSE 0 END)   AS expired_count,
    COALESCE(SUM(fd.quantity), 0)                               AS total_quantity_donated
FROM users u
LEFT JOIN food_donations fd ON u.id = fd.user_id
WHERE u.role = 'restaurant'
GROUP BY u.id, u.restaurant_name;


-- ============================================================
-- SECTION 9: STORED PROCEDURES
-- ============================================================

DELIMITER $$

-- Procedure 1: Add a new food donation with input validation and transaction
CREATE PROCEDURE AddDonation(
    IN  p_user_id      INT,
    IN  p_food_type    VARCHAR(100),
    IN  p_quantity     INT,
    IN  p_expiry_time  DATETIME,
    IN  p_pickup_notes TEXT,
    OUT p_donation_id  INT,
    OUT p_message      VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_donation_id = -1;
        SET p_message = 'Database error while adding donation';
    END;

    IF p_quantity <= 0 THEN
        SET p_donation_id = -1;
        SET p_message = 'Quantity must be greater than 0';
    ELSEIF p_expiry_time <= NOW() THEN
        SET p_donation_id = -1;
        SET p_message = 'Expiry time must be in the future';
    ELSE
        START TRANSACTION;

        INSERT INTO food_donations (user_id, food_type, quantity, expiry_time, pickup_notes)
        VALUES (p_user_id, p_food_type, p_quantity, p_expiry_time, p_pickup_notes);

        SET p_donation_id = LAST_INSERT_ID();
        SET p_message = 'Donation added successfully';

        COMMIT;
    END IF;
END$$


-- Procedure 2: Claim a donation atomically (with row-level lock to prevent race conditions)
CREATE PROCEDURE ClaimDonation(
    IN  p_donation_id  INT,
    IN  p_ngo_user_id  INT,
    OUT p_success      TINYINT,
    OUT p_message      VARCHAR(255)
)
BEGIN
    DECLARE v_status VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = 0;
        SET p_message = 'An error occurred while claiming the donation';
    END;

    START TRANSACTION;

    -- Lock the row to prevent two NGOs claiming simultaneously
    SELECT status INTO v_status
    FROM food_donations
    WHERE id = p_donation_id
    FOR UPDATE;

    IF v_status IS NULL THEN
        SET p_success = 0;
        SET p_message = 'Donation not found';
        ROLLBACK;

    ELSEIF v_status != 'Available' THEN
        SET p_success = 0;
        SET p_message = CONCAT('Donation is already ', v_status);
        ROLLBACK;

    ELSE
        UPDATE food_donations
        SET status = 'Claimed'
        WHERE id = p_donation_id;

        INSERT INTO donation_claims (donation_id, ngo_user_id)
        VALUES (p_donation_id, p_ngo_user_id);

        SAVEPOINT after_claim;

        INSERT INTO audit_log (action, table_name, record_id, old_value, new_value, performed_by)
        VALUES ('CLAIM', 'food_donations', p_donation_id, 'Available', 'Claimed', p_ngo_user_id);

        SET p_success = 1;
        SET p_message = 'Donation claimed successfully';

        COMMIT;
    END IF;
END$$


-- Procedure 3: Expire outdated donations using a CURSOR
CREATE PROCEDURE ExpireOldDonations(OUT p_expired_count INT)
BEGIN
    DECLARE v_done         INT     DEFAULT FALSE;
    DECLARE v_donation_id  INT;
    DECLARE v_count        INT     DEFAULT 0;

    DECLARE expired_cursor CURSOR FOR
        SELECT id
        FROM food_donations
        WHERE expiry_time < NOW()
          AND status = 'Available';

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_expired_count = -1;
    END;

    START TRANSACTION;

    OPEN expired_cursor;

    expire_loop: LOOP
        FETCH expired_cursor INTO v_donation_id;

        IF v_done THEN
            LEAVE expire_loop;
        END IF;

        UPDATE food_donations
        SET status = 'Expired'
        WHERE id = v_donation_id;

        INSERT INTO audit_log (action, table_name, record_id, old_value, new_value)
        VALUES ('AUTO_EXPIRE', 'food_donations', v_donation_id, 'Available', 'Expired');

        SET v_count = v_count + 1;
    END LOOP expire_loop;

    CLOSE expired_cursor;

    SET p_expired_count = v_count;
    COMMIT;
END$$


-- Procedure 4: Summary report for a specific restaurant
CREATE PROCEDURE GetRestaurantReport(IN p_user_id INT)
BEGIN
    SELECT
        u.restaurant_name,
        COUNT(fd.id)                                              AS total_donations,
        COALESCE(SUM(fd.quantity), 0)                            AS total_quantity,
        SUM(CASE WHEN fd.status = 'Available' THEN 1 ELSE 0 END) AS available,
        SUM(CASE WHEN fd.status = 'Claimed'   THEN 1 ELSE 0 END) AS claimed,
        SUM(CASE WHEN fd.status = 'Expired'   THEN 1 ELSE 0 END) AS expired
    FROM users u
    LEFT JOIN food_donations fd ON u.id = fd.user_id
    WHERE u.id = p_user_id
    GROUP BY u.id, u.restaurant_name;
END$$

DELIMITER ;


-- ============================================================
-- SECTION 10: FUNCTIONS
-- ============================================================

DELIMITER $$

-- Function 1: Total number of donations posted by a restaurant
CREATE FUNCTION GetTotalDonations(p_user_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count
    FROM food_donations
    WHERE user_id = p_user_id;
    RETURN v_count;
END$$


-- Function 2: Total quantity successfully claimed from a restaurant
CREATE FUNCTION GetClaimedQuantity(p_user_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_total INT;
    SELECT COALESCE(SUM(quantity), 0) INTO v_total
    FROM food_donations
    WHERE user_id = p_user_id
      AND status  = 'Claimed';
    RETURN v_total;
END$$


-- Function 3: Returns 1 if a donation is still available to claim, else 0
CREATE FUNCTION IsDonationClaimable(p_donation_id INT)
RETURNS TINYINT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_status  VARCHAR(20);
    DECLARE v_expiry  DATETIME;

    SELECT status, expiry_time
    INTO   v_status, v_expiry
    FROM   food_donations
    WHERE  id = p_donation_id;

    IF v_status = 'Available' AND v_expiry > NOW() THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END$$

DELIMITER ;


-- ============================================================
-- SECTION 11: TRIGGERS
-- ============================================================

DELIMITER $$

-- Trigger 1: BEFORE INSERT on food_donations - validate quantity and expiry
CREATE TRIGGER trg_before_donation_insert
BEFORE INSERT ON food_donations
FOR EACH ROW
BEGIN
    IF NEW.quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Quantity must be a positive number';
    END IF;
    IF NEW.expiry_time <= NOW() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Expiry time must be in the future';
    END IF;
END$$


-- Trigger 2: AFTER INSERT on food_donations - log the new donation in audit_log
CREATE TRIGGER trg_after_donation_insert
AFTER INSERT ON food_donations
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (action, table_name, record_id, new_value, performed_by)
    VALUES ('INSERT', 'food_donations', NEW.id, NEW.food_type, NEW.user_id);
END$$


-- Trigger 3: AFTER UPDATE on food_donations - log every status change
CREATE TRIGGER trg_after_donation_update
AFTER UPDATE ON food_donations
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO audit_log (action, table_name, record_id, old_value, new_value)
        VALUES ('STATUS_CHANGE', 'food_donations', NEW.id, OLD.status, NEW.status);
    END IF;
END$$


-- Trigger 4: BEFORE DELETE on food_donations - prevent deleting a claimed donation
CREATE TRIGGER trg_before_donation_delete
BEFORE DELETE ON food_donations
FOR EACH ROW
BEGIN
    IF OLD.status = 'Claimed' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot delete a donation that has already been claimed';
    END IF;
END$$

DELIMITER ;


-- ============================================================
-- SECTION 12: TRANSACTION MANAGEMENT
-- ============================================================

-- Example 1: Successful claim transaction with SAVEPOINT
START TRANSACTION;

    SAVEPOINT before_operations;

    UPDATE food_donations
    SET status = 'Claimed'
    WHERE id = 1 AND status = 'Available';

    SAVEPOINT after_status_update;

    INSERT INTO donation_claims (donation_id, ngo_user_id) VALUES (1, 4);

    INSERT INTO audit_log (action, table_name, record_id, old_value, new_value, performed_by)
    VALUES ('MANUAL_CLAIM', 'food_donations', 1, 'Available', 'Claimed', 4);

COMMIT;


-- Example 2: Rolled-back transaction (simulating a failure scenario)
START TRANSACTION;

    SAVEPOINT initial_state;

    -- Attempt an update that we decide to undo
    UPDATE food_donations SET quantity = quantity - 10 WHERE id = 2;

    -- Something went wrong; roll back only to the savepoint
    ROLLBACK TO SAVEPOINT initial_state;

ROLLBACK;


-- ============================================================
-- SECTION 13: INDEXES (Performance Optimisation)
-- ============================================================

CREATE INDEX idx_donations_user_id  ON food_donations(user_id);
CREATE INDEX idx_donations_status   ON food_donations(status);
CREATE INDEX idx_donations_expiry   ON food_donations(expiry_time);
CREATE INDEX idx_audit_table_record ON audit_log(table_name, record_id);


-- ============================================================
-- SECTION 14: SAMPLE USAGE OF VIEWS, FUNCTIONS & PROCEDURES
-- ============================================================

-- Use the view
SELECT * FROM available_donations_view;
SELECT * FROM restaurant_donation_stats;

-- Use functions
SELECT GetTotalDonations(1)  AS total_by_pizza_palace;
SELECT GetClaimedQuantity(1) AS claimed_quantity_from_pizza_palace;
SELECT IsDonationClaimable(3) AS is_donation_3_claimable;

-- Call procedures
CALL ExpireOldDonations(@expired_count);
SELECT @expired_count AS donations_just_expired;

CALL GetRestaurantReport(1);
