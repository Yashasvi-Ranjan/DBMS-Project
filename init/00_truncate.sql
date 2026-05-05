-- ============================================================
-- TRUNCATE ALL DATA
-- Run this to wipe all existing data from every table.
-- Order matters: child tables must be truncated before parents.
-- ============================================================
SET DEFINE OFF
SET SERVEROUTPUT ON

TRUNCATE TABLE audit_log;
TRUNCATE TABLE donation_claims;
TRUNCATE TABLE food_donations;
TRUNCATE TABLE users;

COMMIT;

