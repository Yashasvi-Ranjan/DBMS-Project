-- ============================================================
-- FILE 3 OF 3 : DML Operations & Test Queries
-- Run this file AFTER 01_schema.sql and 02_plsql.sql
-- No seed data — all data is added through the application.
-- ============================================================
SET DEFINE OFF
SET SERVEROUTPUT ON


-- ----------------------------------------------------------------
-- MAINTENANCE DML
-- Mark any Available donations whose expiry has passed as Expired
-- ----------------------------------------------------------------

UPDATE food_donations
SET status = 'Expired'
WHERE expiry_time < SYSTIMESTAMP
  AND status = 'Available';

COMMIT;

-- Purge Expired donations older than 7 days
DELETE FROM food_donations
WHERE status = 'Expired'
  AND created_at < SYSTIMESTAMP - INTERVAL '7' DAY;

COMMIT;


-- ----------------------------------------------------------------
-- SELECT QUERIES
-- ----------------------------------------------------------------

-- 1. All currently available donations (sorted by nearest expiry first)
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

-- 2. All claimed donations with restaurant and NGO details
SELECT
    fd.id            AS donation_id,
    u_rest.restaurant_name,
    fd.food_type,
    fd.quantity,
    u_ngo.username   AS claimed_by_ngo,
    dc.claimed_at
FROM food_donations fd
INNER JOIN users          u_rest ON fd.user_id    = u_rest.id
INNER JOIN donation_claims dc    ON fd.id          = dc.donation_id
INNER JOIN users          u_ngo  ON dc.ngo_user_id = u_ngo.id;

-- 3. Total donation count per restaurant (LEFT JOIN — includes restaurants with 0 donations)
SELECT
    u.restaurant_name,
    COUNT(fd.id) AS total_donations
FROM users u
LEFT JOIN food_donations fd ON u.id = fd.user_id
WHERE u.role = 'restaurant'
GROUP BY u.id, u.restaurant_name;

-- 4. Aggregate stats per restaurant (INNER JOIN — only restaurants with at least one donation)
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

-- 5. Restaurants with more than one donation, ordered by activity
SELECT
    u.restaurant_name,
    COUNT(fd.id)     AS total_donations,
    SUM(fd.quantity) AS total_quantity
FROM users u
INNER JOIN food_donations fd ON u.id = fd.user_id
GROUP BY u.id, u.restaurant_name
HAVING COUNT(fd.id) > 1
ORDER BY total_donations DESC;

-- 6. Restaurants that donate more than the average number of donations (nested subquery)
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

-- 7. NGOs that have made at least one claim (EXISTS subquery)
SELECT username
FROM users
WHERE role = 'ngo'
  AND EXISTS (
      SELECT 1
      FROM donation_claims
      WHERE ngo_user_id = users.id
  );

-- 8. Donations whose quantity exceeds that restaurant's own average (correlated subquery)
SELECT fd.id, fd.food_type, fd.quantity, u.restaurant_name
FROM food_donations fd
INNER JOIN users u ON fd.user_id = u.id
WHERE fd.quantity > (
    SELECT AVG(fd2.quantity)
    FROM food_donations fd2
    WHERE fd2.user_id = fd.user_id
);


-- ----------------------------------------------------------------
-- VIEW QUERIES
-- ----------------------------------------------------------------

SELECT * FROM available_donations_view;
SELECT * FROM restaurant_donation_stats;


-- ----------------------------------------------------------------
-- TRANSACTION CONTROL DEMO
-- Demonstrates SAVEPOINT, ROLLBACK TO SAVEPOINT, and full ROLLBACK
-- Run manually after adding data through the app.
-- Replace id values with actual IDs from your data.
-- ----------------------------------------------------------------

-- SAVEPOINT before_operations;
--
-- UPDATE food_donations
-- SET status = 'Claimed'
-- WHERE id = <donation_id> AND status = 'Available';
--
-- SAVEPOINT after_status_update;
--
-- INSERT INTO donation_claims (donation_id, ngo_user_id) VALUES (<donation_id>, <ngo_user_id>);
--
-- INSERT INTO audit_log (action, table_name, record_id, old_value, new_value, performed_by)
-- VALUES ('MANUAL_CLAIM', 'food_donations', <donation_id>, 'Available', 'Claimed', <ngo_user_id>);
--
-- COMMIT;
--
-- SAVEPOINT initial_state;
-- UPDATE food_donations SET quantity = quantity - 10 WHERE id = <donation_id>;
-- ROLLBACK TO SAVEPOINT initial_state;
-- ROLLBACK;


-- ----------------------------------------------------------------
-- FUNCTION TEST CALLS
-- Replace user_id / donation_id with real IDs from your data.
-- ----------------------------------------------------------------

-- SELECT GetTotalDonations(<user_id>)   AS total_donations    FROM DUAL;
-- SELECT GetClaimedQuantity(<user_id>)  AS claimed_quantity   FROM DUAL;
-- SELECT IsDonationClaimable(<donation_id>) AS is_claimable   FROM DUAL;


-- ----------------------------------------------------------------
-- PROCEDURE TEST CALLS (anonymous PL/SQL blocks)
-- ----------------------------------------------------------------

-- Test ExpireOldDonations
DECLARE
    v_expired_count NUMBER;
BEGIN
    ExpireOldDonations(v_expired_count);
    DBMS_OUTPUT.PUT_LINE('Donations just expired: ' || v_expired_count);
END;
/

-- Test GetRestaurantReport — replace 1 with a real user_id from your data
-- DECLARE
--     v_cursor          SYS_REFCURSOR;
--     v_restaurant_name VARCHAR2(100);
--     v_total_donations NUMBER;
--     v_total_quantity  NUMBER;
--     v_available       NUMBER;
--     v_claimed         NUMBER;
--     v_expired         NUMBER;
-- BEGIN
--     GetRestaurantReport(<user_id>, v_cursor);
--     LOOP
--         FETCH v_cursor INTO v_restaurant_name, v_total_donations,
--                             v_total_quantity, v_available, v_claimed, v_expired;
--         EXIT WHEN v_cursor%NOTFOUND;
--         DBMS_OUTPUT.PUT_LINE('Restaurant : ' || v_restaurant_name);
--         DBMS_OUTPUT.PUT_LINE('Donations  : ' || v_total_donations);
--         DBMS_OUTPUT.PUT_LINE('Quantity   : ' || v_total_quantity);
--         DBMS_OUTPUT.PUT_LINE('Available  : ' || v_available);
--         DBMS_OUTPUT.PUT_LINE('Claimed    : ' || v_claimed);
--         DBMS_OUTPUT.PUT_LINE('Expired    : ' || v_expired);
--     END LOOP;
--     CLOSE v_cursor;
-- END;
-- /
