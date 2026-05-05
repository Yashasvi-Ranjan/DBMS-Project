-- ============================================================
-- Food Waste Management System
-- Oracle PL/SQL Version
-- Course: UCS310 - Database Management Systems
-- B.Tech 2nd Year
-- ============================================================

SET DEFINE OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR CONTINUE


-- ============================================================
-- SECTION 2: DDL - TABLE CREATION (CREATE)
-- ============================================================

-- Table 1: users
-- Stores both restaurant and NGO accounts.
-- restaurant_name moved here from food_donations to satisfy 3NF.
CREATE TABLE users (
    id              NUMBER          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username        VARCHAR2(100)   UNIQUE NOT NULL,
    password        VARCHAR2(255)   NOT NULL,
    role            VARCHAR2(10)    NOT NULL CHECK (role IN ('restaurant', 'ngo')),
    restaurant_name VARCHAR2(100)   DEFAULT NULL,
    contact_phone   VARCHAR2(15)    DEFAULT NULL,
    is_active       NUMBER(1)       DEFAULT 1,
    created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP
);

-- Table 2: food_donations
-- restaurant_name removed (now derived via JOIN with users).
CREATE TABLE food_donations (
    id              NUMBER          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         NUMBER          NOT NULL,
    food_type       VARCHAR2(100)   NOT NULL,
    quantity        NUMBER          NOT NULL,
    expiry_time     TIMESTAMP       NOT NULL,
    status          VARCHAR2(10)    DEFAULT 'Available'
                                    CHECK (status IN ('Available', 'Claimed', 'Expired')),
    pickup_notes    VARCHAR2(4000)  DEFAULT NULL,
    created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_donation_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_quantity     CHECK (quantity > 0)
);

-- Table 3: donation_claims
-- Tracks which NGO claimed which donation and when.
CREATE TABLE donation_claims (
    id          NUMBER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    donation_id NUMBER      NOT NULL,
    ngo_user_id NUMBER      NOT NULL,
    claimed_at  TIMESTAMP   DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_claim_donation FOREIGN KEY (donation_id) REFERENCES food_donations(id) ON DELETE CASCADE,
    CONSTRAINT fk_claim_ngo      FOREIGN KEY (ngo_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT uq_one_claim      UNIQUE (donation_id)
);

-- Table 4: audit_log
-- Records status changes and key events for accountability.
CREATE TABLE audit_log (
    id           NUMBER          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    action       VARCHAR2(50)    NOT NULL,
    table_name   VARCHAR2(50)    NOT NULL,
    record_id    NUMBER          DEFAULT NULL,
    old_value    VARCHAR2(255)   DEFAULT NULL,
    new_value    VARCHAR2(255)   DEFAULT NULL,
    performed_by NUMBER          DEFAULT NULL,
    action_time  TIMESTAMP       DEFAULT SYSTIMESTAMP
);


-- ============================================================
-- SECTION 3: DDL - ALTER TABLE
-- ============================================================

-- Add a pickup_location column to food_donations
ALTER TABLE food_donations ADD (pickup_location VARCHAR2(255) DEFAULT NULL);

-- Add an email column to users
ALTER TABLE users ADD (email VARCHAR2(150) DEFAULT NULL);

-- Rename email to contact_email for clarity
ALTER TABLE users RENAME COLUMN email TO contact_email;


-- ============================================================
-- SECTION 4: DML - INSERT (Sample Data)
-- ============================================================

-- Note: passwords below are bcrypt hashes of 'password123' (10 rounds).
INSERT INTO users (username, password, role, restaurant_name, contact_phone) VALUES
('pizza_palace', '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LPVSAs9gBTK', 'restaurant', 'Pizza Palace', '9876543210');

INSERT INTO users (username, password, role, restaurant_name, contact_phone) VALUES
('green_bites', '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LPVSAs9gBTK', 'restaurant', 'Green Bites Cafe', '9876543211');

INSERT INTO users (username, password, role, restaurant_name, contact_phone) VALUES
('spice_garden', '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LPVSAs9gBTK', 'restaurant', 'Spice Garden Restaurant', '9876543212');

INSERT INTO users (username, password, role, contact_phone) VALUES
('helping_hands', '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LPVSAs9gBTK', 'ngo', '9876543213');

INSERT INTO users (username, password, role, contact_phone) VALUES
('food_for_all', '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LPVSAs9gBTK', 'ngo', '9876543214');

INSERT INTO food_donations (user_id, food_type, quantity, expiry_time, status, pickup_notes) VALUES
(1, 'Vegetable Biryani', 50, SYSTIMESTAMP + INTERVAL '4' HOUR,  'Available', 'Packed in boxes');

INSERT INTO food_donations (user_id, food_type, quantity, expiry_time, status, pickup_notes) VALUES
(1, 'Bread and Butter',  30, SYSTIMESTAMP + INTERVAL '2' HOUR,  'Available', 'Individually wrapped');

INSERT INTO food_donations (user_id, food_type, quantity, expiry_time, status, pickup_notes) VALUES
(2, 'Mixed Salad',       20, SYSTIMESTAMP + INTERVAL '6' HOUR,  'Available', 'Ready to serve');

INSERT INTO food_donations (user_id, food_type, quantity, expiry_time, status, pickup_notes) VALUES
(2, 'Fruit Juice',       40, SYSTIMESTAMP - INTERVAL '2' HOUR,  'Expired',   'Bottles sealed');

INSERT INTO food_donations (user_id, food_type, quantity, expiry_time, status, pickup_notes) VALUES
(3, 'Dal and Rice',      60, SYSTIMESTAMP + INTERVAL '5' HOUR,  'Available', 'In bulk containers');

INSERT INTO food_donations (user_id, food_type, quantity, expiry_time, status, pickup_notes) VALUES
(3, 'Roti and Sabzi',    45, SYSTIMESTAMP + INTERVAL '3' HOUR,  'Claimed',   'Wrapped in foil');

INSERT INTO donation_claims (donation_id, ngo_user_id) VALUES (6, 4);

COMMIT;


-- ============================================================
-- SECTION 5: DML - UPDATE
-- ============================================================

-- Auto-expire donations whose time has passed
UPDATE food_donations
SET status = 'Expired'
WHERE expiry_time < SYSTIMESTAMP
  AND status = 'Available';

COMMIT;


-- ============================================================
-- SECTION 6: DML - DELETE
-- ============================================================

-- Remove expired donations older than 7 days to keep the table clean
DELETE FROM food_donations
WHERE status = 'Expired'
  AND created_at < SYSTIMESTAMP - INTERVAL '7' DAY;

COMMIT;


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
INNER JOIN users          u_rest ON fd.user_id      = u_rest.id
INNER JOIN donation_claims dc    ON fd.id            = dc.donation_id
INNER JOIN users          u_ngo  ON dc.ngo_user_id   = u_ngo.id;

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
    COUNT(fd.id)     AS total_donations,
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
    COUNT(fd.id)     AS total_donations,
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
        )
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

-- View 1: Available donations with restaurant info
CREATE OR REPLACE VIEW available_donations_view AS
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
  AND fd.expiry_time > SYSTIMESTAMP;

-- View 2: Per-restaurant donation statistics
CREATE OR REPLACE VIEW restaurant_donation_stats AS
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

-- Procedure 1: Add a new food donation with input validation
CREATE OR REPLACE PROCEDURE AddDonation(
    p_user_id      IN  NUMBER,
    p_food_type    IN  VARCHAR2,
    p_quantity     IN  NUMBER,
    p_expiry_time  IN  TIMESTAMP,
    p_pickup_notes IN  VARCHAR2,
    p_donation_id  OUT NUMBER,
    p_message      OUT VARCHAR2
) IS
BEGIN
    IF p_quantity <= 0 THEN
        p_donation_id := -1;
        p_message     := 'Quantity must be greater than 0';
    ELSIF p_expiry_time <= SYSTIMESTAMP THEN
        p_donation_id := -1;
        p_message     := 'Expiry time must be in the future';
    ELSE
        INSERT INTO food_donations (user_id, food_type, quantity, expiry_time, pickup_notes)
        VALUES (p_user_id, p_food_type, p_quantity, p_expiry_time, p_pickup_notes)
        RETURNING id INTO p_donation_id;

        p_message := 'Donation added successfully';
        COMMIT;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_donation_id := -1;
        p_message     := 'Database error while adding donation';
END AddDonation;
/


-- Procedure 2: Claim a donation atomically (with row-level lock to prevent race conditions)
CREATE OR REPLACE PROCEDURE ClaimDonation(
    p_donation_id  IN  NUMBER,
    p_ngo_user_id  IN  NUMBER,
    p_success      OUT NUMBER,
    p_message      OUT VARCHAR2
) IS
    v_status VARCHAR2(20);
BEGIN
    -- Lock the row to prevent two NGOs claiming simultaneously
    SELECT status INTO v_status
    FROM food_donations
    WHERE id = p_donation_id
    FOR UPDATE;

    IF v_status != 'Available' THEN
        p_success := 0;
        p_message := 'Donation is already ' || v_status;
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

        p_success := 1;
        p_message := 'Donation claimed successfully';
        COMMIT;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        p_success := 0;
        p_message := 'Donation not found';
    WHEN OTHERS THEN
        ROLLBACK;
        p_success := 0;
        p_message := 'An error occurred while claiming the donation';
END ClaimDonation;
/


-- Procedure 3: Expire outdated donations using a CURSOR
CREATE OR REPLACE PROCEDURE ExpireOldDonations(p_expired_count OUT NUMBER) IS
    v_count NUMBER := 0;
    CURSOR expired_cursor IS
        SELECT id
        FROM food_donations
        WHERE expiry_time < SYSTIMESTAMP
          AND status = 'Available';
BEGIN
    FOR rec IN expired_cursor LOOP
        UPDATE food_donations
        SET status = 'Expired'
        WHERE id = rec.id;

        INSERT INTO audit_log (action, table_name, record_id, old_value, new_value)
        VALUES ('AUTO_EXPIRE', 'food_donations', rec.id, 'Available', 'Expired');

        v_count := v_count + 1;
    END LOOP;

    p_expired_count := v_count;
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        p_expired_count := -1;
END ExpireOldDonations;
/


-- Procedure 4: Summary report for a specific restaurant
-- Uses SYS_REFCURSOR so callers can fetch the result set
CREATE OR REPLACE PROCEDURE GetRestaurantReport(
    p_user_id IN  NUMBER,
    p_cursor  OUT SYS_REFCURSOR
) IS
BEGIN
    OPEN p_cursor FOR
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
END GetRestaurantReport;
/


-- ============================================================
-- SECTION 10: FUNCTIONS
-- ============================================================

-- Function 1: Total number of donations posted by a restaurant
CREATE OR REPLACE FUNCTION GetTotalDonations(p_user_id IN NUMBER)
RETURN NUMBER IS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM food_donations
    WHERE user_id = p_user_id;
    RETURN v_count;
END GetTotalDonations;
/


-- Function 2: Total quantity successfully claimed from a restaurant
CREATE OR REPLACE FUNCTION GetClaimedQuantity(p_user_id IN NUMBER)
RETURN NUMBER IS
    v_total NUMBER;
BEGIN
    SELECT COALESCE(SUM(quantity), 0) INTO v_total
    FROM food_donations
    WHERE user_id = p_user_id
      AND status  = 'Claimed';
    RETURN v_total;
END GetClaimedQuantity;
/


-- Function 3: Returns 1 if a donation is still available to claim, else 0
CREATE OR REPLACE FUNCTION IsDonationClaimable(p_donation_id IN NUMBER)
RETURN NUMBER IS
    v_status  VARCHAR2(20);
    v_expiry  TIMESTAMP;
BEGIN
    SELECT status, expiry_time
    INTO   v_status, v_expiry
    FROM   food_donations
    WHERE  id = p_donation_id;

    IF v_status = 'Available' AND v_expiry > SYSTIMESTAMP THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END IsDonationClaimable;
/


-- ============================================================
-- SECTION 11: TRIGGERS
-- ============================================================

-- Trigger 1: BEFORE INSERT on food_donations - validate quantity and expiry
CREATE OR REPLACE TRIGGER trg_before_donation_insert
BEFORE INSERT ON food_donations
FOR EACH ROW
BEGIN
    IF :NEW.quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Quantity must be a positive number');
    END IF;
    IF :NEW.expiry_time <= SYSTIMESTAMP THEN
        RAISE_APPLICATION_ERROR(-20002, 'Expiry time must be in the future');
    END IF;
END;
/


-- Trigger 2: AFTER INSERT on food_donations - log the new donation in audit_log
CREATE OR REPLACE TRIGGER trg_after_donation_insert
AFTER INSERT ON food_donations
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (action, table_name, record_id, new_value, performed_by)
    VALUES ('INSERT', 'food_donations', :NEW.id, :NEW.food_type, :NEW.user_id);
END;
/


-- Trigger 3: AFTER UPDATE on food_donations - log every status change
CREATE OR REPLACE TRIGGER trg_after_donation_update
AFTER UPDATE ON food_donations
FOR EACH ROW
BEGIN
    IF :OLD.status != :NEW.status THEN
        INSERT INTO audit_log (action, table_name, record_id, old_value, new_value)
        VALUES ('STATUS_CHANGE', 'food_donations', :NEW.id, :OLD.status, :NEW.status);
    END IF;
END;
/


-- Trigger 4: BEFORE DELETE on food_donations - prevent deleting a claimed donation
CREATE OR REPLACE TRIGGER trg_before_donation_delete
BEFORE DELETE ON food_donations
FOR EACH ROW
BEGIN
    IF :OLD.status = 'Claimed' THEN
        RAISE_APPLICATION_ERROR(-20003, 'Cannot delete a donation that has already been claimed');
    END IF;
END;
/


-- ============================================================
-- SECTION 12: TRANSACTION MANAGEMENT
-- ============================================================

-- Example 1: Successful claim transaction with SAVEPOINT
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
SAVEPOINT initial_state;

UPDATE food_donations SET quantity = quantity - 10 WHERE id = 2;

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

-- Use the views
SELECT * FROM available_donations_view;
SELECT * FROM restaurant_donation_stats;

-- Use functions (Oracle requires FROM DUAL for function calls in SELECT)
SELECT GetTotalDonations(1)   AS total_by_pizza_palace            FROM DUAL;
SELECT GetClaimedQuantity(1)  AS claimed_quantity_from_pizza_palace FROM DUAL;
SELECT IsDonationClaimable(3) AS is_donation_3_claimable           FROM DUAL;

-- Call procedures via anonymous PL/SQL blocks
DECLARE
    v_expired_count NUMBER;
BEGIN
    ExpireOldDonations(v_expired_count);
    DBMS_OUTPUT.PUT_LINE('Donations just expired: ' || v_expired_count);
END;
/

-- GetRestaurantReport returns a cursor; fetch and print results
DECLARE
    v_cursor          SYS_REFCURSOR;
    v_restaurant_name VARCHAR2(100);
    v_total_donations NUMBER;
    v_total_quantity  NUMBER;
    v_available       NUMBER;
    v_claimed         NUMBER;
    v_expired         NUMBER;
BEGIN
    GetRestaurantReport(1, v_cursor);
    LOOP
        FETCH v_cursor INTO v_restaurant_name, v_total_donations,
                            v_total_quantity, v_available, v_claimed, v_expired;
        EXIT WHEN v_cursor%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE('Restaurant : ' || v_restaurant_name);
        DBMS_OUTPUT.PUT_LINE('Donations  : ' || v_total_donations);
        DBMS_OUTPUT.PUT_LINE('Quantity   : ' || v_total_quantity);
        DBMS_OUTPUT.PUT_LINE('Available  : ' || v_available);
        DBMS_OUTPUT.PUT_LINE('Claimed    : ' || v_claimed);
        DBMS_OUTPUT.PUT_LINE('Expired    : ' || v_expired);
    END LOOP;
    CLOSE v_cursor;
END;
/
