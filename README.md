# DBMS Project Synopsis — Food Waste Reduction Platform

---

## 1. Title Page

| Field | Details |
|---|---|
| **Project Title** | Food Waste Reduction Platform |
| **Course Name & Code** | UCS310 – Database Management Systems |
| **Degree & Year** | B.Tech (2nd Year) |
| **Department** | Computer Science and Engineering |
| **Institute Name** | Thapar Institute of Engineering & Technology |
| **Group Members** | Vansh Panwar (Roll No: ___________) |
| | Kamesh Yadav (Roll No: ___________) |
| | Yashasvi Ranjan (Roll No: ___________) |
| **Lab Instructor** | Dr. Shashank Singh |
| **Academic Year** | 2026–2027 |

---

## 2. Introduction

The **Food Waste Reduction Platform** is a database-driven web application designed to connect restaurants with surplus food to NGOs that distribute food to people in need.

Food wastage is a major social and environmental issue. At the same time, NGOs often struggle to source food in a timely manner. Traditional coordination through phone calls and messages leads to miscommunication, duplication, and poor tracking.

A Database Management System (DBMS) provides:
- Structured data storage with integrity constraints
- Role-based access control
- Efficient query processing using SQL
- Secure multi-user operations with transaction management
- Automation through triggers and stored procedures

This project emphasises relational database design, normalisation (up to 3NF), and complete backend implementation using Oracle PL/SQL — including stored procedures, functions, triggers, cursors, views, and transaction control. Oracle Database 21c Express Edition (XE) is installed locally and accessed via Oracle SQL Developer.

---

## 3. Problem Statement

Currently, food donation processes are mostly informal and unstructured. This results in:
- No centralised record of donations
- Duplicate claims on the same donation
- Delayed pickups due to lack of real-time visibility
- No structured authentication or role separation
- No automated status lifecycle (Available → Claimed / Expired)
- No accountability trail for who claimed what and when

The proposed system provides a structured relational database solution to manage restaurants, NGOs, and donation records efficiently, with full Oracle PL/SQL support including stored procedures, functions, triggers, and cursors.

---

## 4. Objectives of the Project

- To design an Entity–Relationship (ER) model for the food donation domain
- To convert the ER model into a normalised relational schema
- To identify functional dependencies and normalise the database up to Third Normal Form (3NF)
- To implement complete DDL and DML SQL commands (CREATE, ALTER, DROP, INSERT, UPDATE, DELETE)
- To write advanced SELECT queries using JOINs, subqueries, aggregate functions, GROUP BY, HAVING, and Views
- To implement Oracle PL/SQL stored procedures, user-defined functions, triggers, and cursors
- To ensure data consistency and atomicity using transaction management (COMMIT, ROLLBACK, SAVEPOINT)
- To enforce role-based access and donation lifecycle management through backend logic

---

## 5. Scope of the Project

**Users:**
- **Restaurant** — Registers, logs in, creates and tracks food donations
- **NGO** — Registers, logs in, views available donations, claims donations

**Modules:**
- User Registration & Authentication Module
- Donation Creation Module
- Donation Listing Module (with JOIN-based retrieval)
- Donation Claim Workflow (via Express API transaction with row-level locking)
- Expiry & Status Lifecycle Management Module (trigger + cursor procedure)
- Audit Logging Module (via triggers writing to `audit_log` table)

The system focuses primarily on backend database operations and API-based integration.

---

## 6. Proposed System Description

**Technology Stack:**

| Layer | Technology |
|---|---|
| Database | Oracle Database 21c Express Edition (XE) |
| Backend | Node.js + Express.js |
| Frontend | HTML, CSS, JavaScript |
| Authentication | JWT + bcryptjs |
| DB Interface | Oracle SQL Developer / SQLcl |

**Working of the System:**
1. Restaurant registers (username, password, restaurant name stored in `users` table).
2. Restaurant logs in and creates a food donation entry.
3. A **BEFORE INSERT trigger** validates quantity and expiry time at the database level using `RAISE_APPLICATION_ERROR`.
4. An **AFTER INSERT trigger** automatically writes a record to `audit_log`.
5. Donation details are stored in the `food_donations` table.
6. NGO logs in and views available donations via a JOIN query on `food_donations` and `users`.
7. NGO claims a donation — the `ClaimDonation` PL/SQL procedure locks the selected donation row with `SELECT ... FOR UPDATE`, updates the donation status, inserts a `donation_claims` record, and commits atomically to prevent race conditions.
8. An **AFTER UPDATE trigger** logs every status change to `audit_log`.
9. Expired donations are auto-updated by the `ExpireOldDonations` stored procedure (uses a cursor FOR loop to iterate row by row).

---

## 7. Database Design

### 7.1 Entities Identified

1. **User** — Represents both restaurants and NGOs
2. **Food Donation** — A surplus food listing created by a restaurant
3. **Donation Claim** — Records which NGO claimed which donation and when
4. **Audit Log** — Tracks all key database changes for accountability

### 7.2 ER Design (Textual Description)

**users Entity:**
- `id` — Primary Key, `GENERATED ALWAYS AS IDENTITY`
- `username` — Unique, NOT NULL
- `password` — NOT NULL (bcrypt hash)
- `role` — `VARCHAR2(10)` with `CHECK (role IN ('restaurant','ngo'))`, NOT NULL
- `restaurant_name` — VARCHAR, only for restaurant role *(moved here from `food_donations` to satisfy 3NF)*
- `contact_phone`, `contact_email`, `is_active`, `created_at`

**food_donations Entity:**
- `id` — Primary Key, `GENERATED ALWAYS AS IDENTITY`
- `user_id` — Foreign Key → users.id (ON DELETE CASCADE)
- `food_type`, `quantity`, `expiry_time`
- `status` — `VARCHAR2(10)` with `CHECK (status IN ('Available','Claimed','Expired'))`, DEFAULT 'Available'
- `pickup_notes`, `pickup_location`, `created_at`

**donation_claims Entity:**
- `id` — Primary Key
- `donation_id` — Foreign Key → food_donations.id, UNIQUE (one claim per donation)
- `ngo_user_id` — Foreign Key → users.id
- `claimed_at` — TIMESTAMP

**audit_log Entity:**
- `id` — Primary Key
- `action`, `table_name`, `record_id`, `old_value`, `new_value`, `performed_by`, `action_time`

**Relationships:**
- `users` **(1) ─── (M)** `food_donations` — A restaurant posts many donations
- `food_donations` **(1) ─── (1)** `donation_claims` — A donation is claimed at most once
- `users` [NGO] **(1) ─── (M)** `donation_claims` — An NGO can claim many donations

### 7.3 Relational Schema

```
users(id PK, username UNIQUE NOT NULL, password NOT NULL,
      role VARCHAR2(10) CHECK('restaurant','ngo') NOT NULL,
      restaurant_name, contact_phone, contact_email,
      is_active DEFAULT 1, created_at)

food_donations(id PK, user_id FK→users.id (ON DELETE CASCADE),
               food_type NOT NULL, quantity NOT NULL,
               expiry_time NOT NULL,
               status VARCHAR2(10) CHECK('Available','Claimed','Expired') DEFAULT 'Available',
               pickup_notes, pickup_location, created_at)

donation_claims(id PK, donation_id FK→food_donations.id UNIQUE,
                ngo_user_id FK→users.id, claimed_at)

audit_log(id PK, action, table_name, record_id,
          old_value, new_value, performed_by, action_time)
```

---

## 8. Normalisation

### 8.1 Original Schema (Before Normalisation)

```
users(id, username, password, role, created_at)
food_donations(id, user_id, restaurant_name, food_type,
               quantity, expiry_time, status, created_at)
```

### 8.2 First Normal Form (1NF)

**Condition:** All attributes must be atomic; no repeating groups; every row uniquely identifiable.

**Analysis:**
- All columns hold single, indivisible values (no multi-valued attributes).
- Each table has a surrogate primary key (`id` AUTO_INCREMENT).
- No repeating groups exist.

✔ Both tables satisfy **1NF**.

### 8.3 Second Normal Form (2NF)

**Condition:** Must be in 1NF and every non-key attribute must fully depend on the *entire* primary key (no partial dependencies).

**Analysis:**
- Both tables use a **single-column primary key** (`id`), so partial dependencies are structurally impossible.

✔ Both tables satisfy **2NF**.

### 8.4 Third Normal Form (3NF)

**Condition:** Must be in 2NF and there must be no transitive dependencies.

**Analysis:**

-- 3NF satisfied:
users(id, username, password, role, restaurant_name, ...)
food_donations(id, user_id, food_type, quantity, ...)

-- restaurant_name is now retrieved via JOIN:
SELECT u.restaurant_name, fd.*
FROM food_donations fd
INNER JOIN users u ON fd.user_id = u.id;
```

### 8.5 Final Functional Dependencies (Normalised Schema)

```
users:           id → username, password, role, restaurant_name,
                      contact_phone, contact_email, created_at

food_donations:  id → user_id, food_type, quantity, expiry_time,
                      status, pickup_notes, pickup_location, created_at

donation_claims: id → donation_id, ngo_user_id, claimed_at

audit_log:       id → action, table_name, record_id, old_value,
                      new_value, performed_by, action_time
```

In each table, every non-key attribute depends *directly* on the primary key alone — no partial or transitive dependencies remain.

**✔ The final schema is normalised up to Third Normal Form (3NF).**

---

## 9. Database Implementation

### 9.0 SQL Script Files

The database initialisation is split across three files, to be run in order in Oracle SQL Developer (F5 — Run Script):

| File | Contents | Run Order |
|---|---|---|
| `init/01_schema.sql` | CREATE TABLE, ALTER TABLE, CREATE INDEX, CREATE VIEW | 1st |
| `init/02_plsql.sql` | Stored Procedures, Functions, Triggers | 2nd |
| `init/03_data_ops.sql` | Maintenance DML, SELECT queries, procedure test calls | 3rd |

### 9.1 SQL Implementation

**DDL Commands Used:**

```sql
-- Create tables with constraints
CREATE TABLE users (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR2(100) UNIQUE NOT NULL,
    role VARCHAR2(10) CHECK (role IN ('restaurant','ngo')) NOT NULL, ...
);
CREATE TABLE food_donations ( ... );
CREATE TABLE donation_claims ( ... );
CREATE TABLE audit_log ( ... );

-- Alter tables
ALTER TABLE food_donations ADD (pickup_location VARCHAR2(255) DEFAULT NULL);
ALTER TABLE users ADD (email VARCHAR2(150) DEFAULT NULL);
ALTER TABLE users RENAME COLUMN email TO contact_email;
```

**DML Commands Used:**

```sql
-- INSERT: user registration, donation creation, claim recording
INSERT INTO users (username, password, role, restaurant_name) VALUES (:username, :password, :role, :restaurant_name);
INSERT INTO food_donations (user_id, food_type, quantity, expiry_time) VALUES (:user_id, :food_type, :quantity, :expiry_time);

-- UPDATE: status transitions
UPDATE food_donations SET status = 'Expired'
WHERE expiry_time < SYSTIMESTAMP AND status = 'Available';

-- DELETE: purge expired donations older than 7 days
DELETE FROM food_donations
WHERE status = 'Expired' AND created_at < SYSTIMESTAMP - INTERVAL '7' DAY;
```

**Advanced SELECT Queries:**

INNER JOIN — Donations with restaurant names (3NF-compliant retrieval):
```sql
SELECT fd.id, u.restaurant_name, fd.food_type, fd.quantity,
       fd.expiry_time, fd.status
FROM food_donations fd
INNER JOIN users u ON fd.user_id = u.id
WHERE fd.status = 'Available'
ORDER BY fd.expiry_time ASC;
```

Multi-table JOIN — Claimed donations with NGO info:
```sql
SELECT fd.id, u_rest.restaurant_name, fd.food_type,
       u_ngo.username AS claimed_by_ngo, dc.claimed_at
FROM food_donations fd
INNER JOIN users u_rest       ON fd.user_id     = u_rest.id
INNER JOIN donation_claims dc ON fd.id          = dc.donation_id
INNER JOIN users u_ngo        ON dc.ngo_user_id = u_ngo.id;
```

Aggregate Functions + GROUP BY + HAVING:
```sql
SELECT u.restaurant_name,
       COUNT(fd.id)     AS total_donations,
       SUM(fd.quantity) AS total_quantity,
       AVG(fd.quantity) AS avg_quantity,
       MAX(fd.quantity) AS max_quantity,
       MIN(fd.quantity) AS min_quantity
FROM users u
INNER JOIN food_donations fd ON u.id = fd.user_id
GROUP BY u.id, u.restaurant_name
HAVING COUNT(fd.id) > 1
ORDER BY total_donations DESC;
```

Nested Subquery — Restaurants with above-average donation count:
```sql
SELECT username, restaurant_name FROM users
WHERE id IN (
    SELECT user_id FROM food_donations
    GROUP BY user_id
    HAVING COUNT(*) > (
        SELECT AVG(cnt)
        FROM (SELECT COUNT(*) AS cnt FROM food_donations GROUP BY user_id) t
    )
);
```

EXISTS Subquery — NGOs that have claimed at least one donation:
```sql
SELECT username FROM users
WHERE role = 'ngo'
  AND EXISTS (
      SELECT 1 FROM donation_claims WHERE ngo_user_id = users.id
  );
```

**Views:**

```sql
-- View 1: Available donations with full restaurant details
CREATE OR REPLACE VIEW available_donations_view AS
SELECT fd.id, u.restaurant_name, u.contact_phone,
       fd.food_type, fd.quantity, fd.expiry_time,
       fd.pickup_notes, fd.pickup_location, fd.created_at
FROM food_donations fd
INNER JOIN users u ON fd.user_id = u.id
WHERE fd.status = 'Available' AND fd.expiry_time > SYSTIMESTAMP;

-- View 2: Per-restaurant donation statistics
CREATE OR REPLACE VIEW restaurant_donation_stats AS
SELECT u.restaurant_name,
  COUNT(fd.id)                                            AS total_donations,
  SUM(CASE WHEN fd.status='Available' THEN 1 ELSE 0 END) AS available_count,
  SUM(CASE WHEN fd.status='Claimed'   THEN 1 ELSE 0 END) AS claimed_count,
  SUM(CASE WHEN fd.status='Expired'   THEN 1 ELSE 0 END) AS expired_count,
  COALESCE(SUM(fd.quantity), 0)                           AS total_quantity
FROM users u
LEFT JOIN food_donations fd ON u.id = fd.user_id
WHERE u.role = 'restaurant'
GROUP BY u.id, u.restaurant_name;
```

---

### 9.2 Oracle PL/SQL Stored Procedures, Functions, Triggers & Cursors

**Stored Procedures (5 implemented):**

**1. AddDonation** — Validates input and inserts a donation; uses `RETURNING INTO` to capture the generated ID:
```sql
CREATE OR REPLACE PROCEDURE AddDonation(
    p_user_id IN NUMBER, p_food_type IN VARCHAR2,
    p_quantity IN NUMBER, p_expiry_time IN TIMESTAMP,
    p_pickup_notes IN VARCHAR2,
    p_donation_id OUT NUMBER, p_message OUT VARCHAR2)
IS
BEGIN
  IF p_quantity <= 0 THEN
    p_donation_id := -1;
    p_message := 'Quantity must be greater than 0';
  ELSIF p_expiry_time <= SYSTIMESTAMP THEN
    p_donation_id := -1;
    p_message := 'Expiry time must be in the future';
  ELSE
    INSERT INTO food_donations(user_id, food_type, quantity, expiry_time, pickup_notes)
    VALUES(p_user_id, p_food_type, p_quantity, p_expiry_time, p_pickup_notes)
    RETURNING id INTO p_donation_id;
    p_message := 'Donation added successfully';
    COMMIT;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    p_donation_id := -1;
    p_message := 'Database error while adding donation';
END AddDonation;
```

**2. ClaimDonation** — Atomically claims a donation with row-level locking:
```sql
CREATE OR REPLACE PROCEDURE ClaimDonation(
    p_donation_id IN NUMBER, p_ngo_user_id IN NUMBER,
    p_success OUT NUMBER, p_message OUT VARCHAR2)
IS
  v_status VARCHAR2(20);
BEGIN
  SELECT status INTO v_status
  FROM food_donations WHERE id = p_donation_id FOR UPDATE;

  IF v_status != 'Available' THEN
    p_success := 0;
    p_message := 'Donation is already ' || v_status;
    ROLLBACK;
  ELSE
    UPDATE food_donations SET status = 'Claimed' WHERE id = p_donation_id;
    INSERT INTO donation_claims(donation_id, ngo_user_id)
    VALUES(p_donation_id, p_ngo_user_id);
    SAVEPOINT after_claim;
    INSERT INTO audit_log(action, table_name, record_id, old_value, new_value)
    VALUES('CLAIM', 'food_donations', p_donation_id, 'Available', 'Claimed');
    p_success := 1;
    p_message := 'Donation claimed successfully';
    COMMIT;
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ROLLBACK; p_success := 0; p_message := 'Donation not found';
  WHEN OTHERS THEN
    ROLLBACK; p_success := 0; p_message := 'An error occurred';
END ClaimDonation;
```

**3. ExpireOldDonations** — Uses a CURSOR FOR LOOP to iterate and expire overdue donations:
```sql
CREATE OR REPLACE PROCEDURE ExpireOldDonations(p_expired_count OUT NUMBER) IS
  v_count NUMBER := 0;
  CURSOR expired_cursor IS
    SELECT id FROM food_donations
    WHERE expiry_time < SYSTIMESTAMP AND status = 'Available';
BEGIN
  FOR rec IN expired_cursor LOOP
    UPDATE food_donations SET status = 'Expired' WHERE id = rec.id;
    INSERT INTO audit_log(action, table_name, record_id, old_value, new_value)
    VALUES('AUTO_EXPIRE', 'food_donations', rec.id, 'Available', 'Expired');
    v_count := v_count + 1;
  END LOOP;
  p_expired_count := v_count;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN ROLLBACK; p_expired_count := -1;
END ExpireOldDonations;
```

**4. GetExpiredDonations** — Returns all expired donations with restaurant details via a `SYS_REFCURSOR` OUT parameter:
```sql
CREATE OR REPLACE PROCEDURE GetExpiredDonations(p_cursor OUT SYS_REFCURSOR) IS
BEGIN
    OPEN p_cursor FOR
        SELECT fd.id, u.restaurant_name, fd.food_type,
               fd.quantity, fd.expiry_time, fd.created_at
        FROM food_donations fd
        INNER JOIN users u ON fd.user_id = u.id
        WHERE fd.status = 'Expired'
        ORDER BY fd.expiry_time DESC;
END GetExpiredDonations;
```

**5. GetRestaurantReport** — Returns an aggregated summary via a `SYS_REFCURSOR` OUT parameter.
```sql
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
```

---

**User-Defined Functions (3 implemented):**

```sql
-- Returns total donation count for a restaurant user
CREATE OR REPLACE FUNCTION GetTotalDonations(p_user_id IN NUMBER)
RETURN NUMBER IS
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM food_donations WHERE user_id = p_user_id;
  RETURN v_count;
END GetTotalDonations;

-- Returns total quantity of food successfully claimed from a restaurant
CREATE OR REPLACE FUNCTION GetClaimedQuantity(p_user_id IN NUMBER)
RETURN NUMBER IS
  v_total NUMBER;
BEGIN
  SELECT COALESCE(SUM(quantity), 0) INTO v_total
  FROM food_donations WHERE user_id = p_user_id AND status = 'Claimed';
  RETURN v_total;
END GetClaimedQuantity;

-- Returns 1 if a donation is still claimable (Available + not expired), else 0
CREATE OR REPLACE FUNCTION IsDonationClaimable(p_donation_id IN NUMBER)
RETURN NUMBER IS
  v_status VARCHAR2(20);
  v_expiry TIMESTAMP;
BEGIN
  SELECT status, expiry_time INTO v_status, v_expiry
  FROM food_donations WHERE id = p_donation_id;
  IF v_status = 'Available' AND v_expiry > SYSTIMESTAMP THEN RETURN 1;
  ELSE RETURN 0; END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN RETURN 0;
END IsDonationClaimable;
```

---

**Triggers (4 implemented):**

| Trigger Name | Event | Purpose |
|---|---|---|
| `trg_before_donation_insert` | BEFORE INSERT on food_donations | Validates quantity > 0 and expiry_time is in the future; raises `RAISE_APPLICATION_ERROR` on failure |
| `trg_after_donation_insert` | AFTER INSERT on food_donations | Writes a new-donation record to `audit_log` |
| `trg_after_donation_update` | AFTER UPDATE on food_donations | Logs every status change (old → new value) to `audit_log` |
| `trg_before_donation_delete` | BEFORE DELETE on food_donations | Prevents deletion of a 'Claimed' donation; raises `RAISE_APPLICATION_ERROR` |

Example trigger:
```sql
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
```

---

**Exception Handling:**

All stored procedures use an `EXCEPTION WHEN OTHERS THEN` block to catch runtime errors, roll back the active transaction, and return a failure flag and message to the caller.

```sql
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    p_success := 0;
    p_message := 'An error occurred; transaction rolled back';
```

---

## 10. Transaction Management & Concurrency Control

### 10.1 Transaction Control Statements

| Statement | Purpose |
|---|---|
| *(auto-started)* | Oracle begins a transaction automatically on the first DML statement |
| `SAVEPOINT <name>` | Marks an intermediate rollback point within a transaction |
| `ROLLBACK TO SAVEPOINT <name>` | Undoes work since the savepoint without aborting the whole transaction |
| `COMMIT` | Permanently writes all changes to disk |
| `ROLLBACK` | Discards all changes in the active transaction |

**Example — Successful claim with SAVEPOINT:**
```sql
SAVEPOINT before_claim;
UPDATE food_donations SET status = 'Claimed'
WHERE id = p_donation_id AND status = 'Available';
SAVEPOINT after_status_update;
INSERT INTO donation_claims(donation_id, ngo_user_id)
VALUES(p_donation_id, p_ngo_user_id);
INSERT INTO audit_log(action, table_name, record_id, old_value, new_value)
VALUES('CLAIM', 'food_donations', p_donation_id, 'Available', 'Claimed');
COMMIT;
```

**Example — Rollback on failure:**
```sql
SAVEPOINT initial_state;
UPDATE food_donations SET quantity = quantity - 10 WHERE id = 2;
ROLLBACK TO SAVEPOINT initial_state;
ROLLBACK;
```

### 10.2 ACID Properties

| Property | How It Is Ensured |
|---|---|
| **Atomicity** | Claim operations in the Express API transaction and donation insertion in `AddDonation` either commit fully or roll back entirely |
| **Consistency** | Triggers enforce business rules (quantity > 0, future expiry); FK constraints prevent orphan records; ENUM restricts status values |
| **Isolation** | `SELECT ... FOR UPDATE` in the claim transaction locks the row so two NGOs cannot claim the same donation concurrently |
| **Durability** | Every committed transaction is persisted by Oracle's redo log to disk |

### 10.3 Concurrency Control

The NGO claim workflow uses **pessimistic locking** (`SELECT ... FOR UPDATE`) inside an Oracle transaction to prevent race conditions. Only one transaction can hold the row lock at a time; a second concurrent claim must wait, then sees status = 'Claimed' and is safely rejected.

The `UNIQUE KEY uq_one_claim (donation_id)` in `donation_claims` provides an additional database-level guard against duplicate claims even without the lock.

---

## 11. Tools & Technologies Used

| Category | Tool / Technology | Purpose |
|---|---|---|
| DBMS | Oracle Database 21c Express Edition (XE) | Relational database, PL/SQL stored procedures, triggers, functions |
| DB Interface | Oracle SQL Developer | Schema design, query testing, and running SQL init scripts |
| Query Language | SQL (DDL, DML, DQL) | All database operations |
| Procedural SQL | Oracle PL/SQL — Procedures, Functions, Triggers, Cursors | DB-level business logic & automation |
| Backend | Node.js + Express.js | REST API and routing |
| Authentication | JWT + bcryptjs | Secure token-based auth, password hashing |
| Frontend | HTML, CSS, JavaScript | User interface for restaurants and NGOs |

---

## 12. Expected Outcomes

- A properly structured, fully normalised (3NF) relational database with 4 tables
- Complete SQL implementation: DDL (CREATE, ALTER, DROP), DML (INSERT, UPDATE, DELETE), and advanced SELECT (JOINs, subqueries, aggregates, GROUP BY, HAVING, Views)
- 5 stored procedures provided in the SQL script for core database workflows
- 3 user-defined functions for data querying
- 4 database triggers for input validation and audit logging
- Cursor-based batch processing for expiry management
- ACID-compliant transactions with row-level concurrency control
- Secure, role-based authentication using JWT and bcrypt
- Efficient food donation tracking that reduces food wastage
- Improved data consistency, integrity, and accountability via audit logging
- Faster coordination between restaurants and NGOs through real-time donation visibility
- Reduction in food wastage through timely and structured donation management
