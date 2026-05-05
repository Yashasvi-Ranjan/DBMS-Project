-- ============================================================
-- FILE 1 OF 3 : Schema Definition
-- Run this file FIRST, before 02_plsql.sql and 03_data_ops.sql
-- ============================================================
SET DEFINE OFF
SET SERVEROUTPUT ON


-- ----------------------------------------------------------------
-- TABLES
-- ----------------------------------------------------------------

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

CREATE TABLE donation_claims (
    id          NUMBER      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    donation_id NUMBER      NOT NULL,
    ngo_user_id NUMBER      NOT NULL,
    claimed_at  TIMESTAMP   DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_claim_donation FOREIGN KEY (donation_id) REFERENCES food_donations(id) ON DELETE CASCADE,
    CONSTRAINT fk_claim_ngo      FOREIGN KEY (ngo_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT uq_one_claim      UNIQUE (donation_id)
);

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


-- ----------------------------------------------------------------
-- ALTER TABLE (column additions / renames)
-- ----------------------------------------------------------------

ALTER TABLE food_donations ADD (pickup_location VARCHAR2(255) DEFAULT NULL);

ALTER TABLE users ADD (email VARCHAR2(150) DEFAULT NULL);

ALTER TABLE users RENAME COLUMN email TO contact_email;


-- ----------------------------------------------------------------
-- INDEXES
-- ----------------------------------------------------------------

CREATE INDEX idx_donations_user_id  ON food_donations(user_id);
CREATE INDEX idx_donations_status   ON food_donations(status);
CREATE INDEX idx_donations_expiry   ON food_donations(expiry_time);
CREATE INDEX idx_audit_table_record ON audit_log(table_name, record_id);


-- ----------------------------------------------------------------
-- VIEWS
-- ----------------------------------------------------------------

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
