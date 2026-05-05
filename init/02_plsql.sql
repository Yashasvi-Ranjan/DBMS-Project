-- ============================================================
-- FILE 2 OF 3 : PL/SQL Objects (Procedures, Functions, Triggers)
-- Run this file AFTER 01_schema.sql and BEFORE 03_data_ops.sql
-- ============================================================
SET DEFINE OFF
SET SERVEROUTPUT ON


-- ----------------------------------------------------------------
-- PROCEDURES
-- ----------------------------------------------------------------

-- Adds a new food donation after validating quantity and expiry time.
-- Returns the new donation id (or -1 on failure) and a status message.
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


-- Claims an available donation for an NGO and logs the action to audit_log.
-- Uses SELECT FOR UPDATE to prevent concurrent double-claims.
CREATE OR REPLACE PROCEDURE ClaimDonation(
    p_donation_id  IN  NUMBER,
    p_ngo_user_id  IN  NUMBER,
    p_success      OUT NUMBER,
    p_message      OUT VARCHAR2
) IS
    v_status VARCHAR2(20);
BEGIN
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


-- Iterates over all Available donations past their expiry time,
-- marks each as Expired, and writes an audit entry per record.
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


-- Returns a REF CURSOR with a summary report for a given restaurant user.
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


-- ----------------------------------------------------------------
-- FUNCTIONS
-- ----------------------------------------------------------------

-- Returns the total number of donations made by a given user.
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


-- Returns the total quantity of Claimed donations for a given user.
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


-- Returns 1 if the donation is Available and not yet expired, else 0.
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


-- ----------------------------------------------------------------
-- TRIGGERS
-- ----------------------------------------------------------------

-- Rejects inserts where quantity <= 0 or expiry_time is in the past.
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


-- Writes an INSERT audit entry for every new food_donation row.
CREATE OR REPLACE TRIGGER trg_after_donation_insert
AFTER INSERT ON food_donations
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (action, table_name, record_id, new_value, performed_by)
    VALUES ('INSERT', 'food_donations', :NEW.id, :NEW.food_type, :NEW.user_id);
END;
/


-- Logs any status change on a food_donation row to audit_log.
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


-- Prevents deletion of donations that have already been claimed.
CREATE OR REPLACE TRIGGER trg_before_donation_delete
BEFORE DELETE ON food_donations
FOR EACH ROW
BEGIN
    IF :OLD.status = 'Claimed' THEN
        RAISE_APPLICATION_ERROR(-20003, 'Cannot delete a donation that has already been claimed');
    END IF;
END;
/
