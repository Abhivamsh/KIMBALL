-- ============================================================
-- PROJECT 9
-- CUSTOMER HISTORY MANAGEMENT
-- SCD TYPE 1 AND SCD TYPE 2
-- ============================================================

USE WAREHOUSE STAR_SCHEMA_WH;
-- ============================================================
-- TASK 1 — CREATE DATABASE AND SCHEMA
-- ============================================================

CREATE DATABASE CUSTOMER_HISTORY_DB;

CREATE SCHEMA CUSTOMER_HISTORY_DB.CUSTOMER_SCHEMA;

USE DATABASE CUSTOMER_HISTORY_DB;

USE SCHEMA CUSTOMER_SCHEMA;

List @Customer_Stage

-- REMOVE @CUSTOMER_STAGE/customers_updates.csv

-- ============================================================
-- TASK 2 — CREATE SCD TYPE 1 TABLE
-- ============================================================

CREATE TABLE DIM_CUSTOMER_TYPE1 (
    CUSTOMER_KEY INT,
    CUSTOMER_ID INT,
    CUSTOMER_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    MEMBERSHIP VARCHAR(30),
    SEGMENT VARCHAR(30)
);

DESC TABLE DIM_CUSTOMER_TYPE1;


-- ============================================================
-- TASK 3 — LOAD INITIAL TYPE 1 DATA
-- ============================================================

-- Assumption:
-- customers_initial.csv is already available in CUSTOMER_STAGE
-- and CUSTOMER_CSV_FORMAT was created in the previous project.

INSERT INTO DIM_CUSTOMER_TYPE1
(
    CUSTOMER_KEY,
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    SEGMENT
)
SELECT
    ROW_NUMBER() OVER (ORDER BY CUSTOMER_ID),
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    SEGMENT
FROM DIM_CUSTOMER;


-- Check initial Type 1 records

SELECT *
FROM DIM_CUSTOMER_TYPE1
ORDER BY CUSTOMER_ID;


-- ============================================================
-- TASK 4 — APPLY SCD TYPE 1 UPDATES
-- ============================================================

-- Type 1 means:
-- UPDATE the existing row.
-- DO NOT create another row.
-- History is NOT preserved.

UPDATE DIM_CUSTOMER_TYPE1 d
SET
    CITY = u.CITY,
    STATE = u.STATE,
    MEMBERSHIP = u.MEMBERSHIP,
    SEGMENT = u.SEGMENT
FROM CUSTOMER_UPDATES u
WHERE d.CUSTOMER_ID = u.CUSTOMER_ID;


-- Check Type 1 result

SELECT *
FROM DIM_CUSTOMER_TYPE1
ORDER BY CUSTOMER_ID;


-- Expected:
--
-- 101 Amit Sharma  Bengaluru   Karnataka      Gold
-- 102 Priya Reddy  Warangal    Telangana      Gold
-- 103 Rahul Verma  Chennai     Tamil Nadu     Gold
-- 104 Neha Patel   Hyderabad   Telangana      Platinum
-- 105 Arjun Gupta  Nagpur      Maharashtra    Bronze


-- ============================================================
-- TASK 7 — CREATE TYPE 2 TABLE
-- ============================================================

CREATE TABLE DIM_CUSTOMER_TYPE2 (
    CUSTOMER_KEY INT,
    CUSTOMER_ID INT,
    CUSTOMER_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    MEMBERSHIP VARCHAR(30),
    SEGMENT VARCHAR(30),
    EFFECTIVE_DATE DATE,
    EXPIRY_DATE DATE,
    IS_CURRENT BOOLEAN
);


-- Check structure

DESC TABLE DIM_CUSTOMER_TYPE2;


-- ============================================================
-- TASK 9 — LOAD INITIAL TYPE 2 RECORDS
-- ============================================================

-- Every initial customer starts with:
--
-- EFFECTIVE_DATE = 2026-01-01
-- EXPIRY_DATE    = 9999-12-31
-- IS_CURRENT     = TRUE

INSERT INTO DIM_CUSTOMER_TYPE2
(
    CUSTOMER_KEY,
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    SEGMENT,
    EFFECTIVE_DATE,
    EXPIRY_DATE,
    IS_CURRENT
)
SELECT
    ROW_NUMBER() OVER (ORDER BY CUSTOMER_ID),
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    SEGMENT,
    '2026-01-01',
    '9999-12-31',
    TRUE
FROM DIM_CUSTOMER;


-- Check initial Type 2 data

SELECT *
FROM DIM_CUSTOMER_TYPE2
ORDER BY CUSTOMER_ID;


-- Expected:
-- Total records = 5
-- Current records = 5


-- ============================================================
-- TASK 10 — APPLY TYPE 2 CHANGES
-- STEP 1 — EXPIRE OLD RECORDS
-- ============================================================

-- For changed customers:
-- OLD record is closed.
--
-- IS_CURRENT:
-- TRUE  → FALSE
--
-- EXPIRY_DATE:
-- changes to the day before the new version starts.

UPDATE DIM_CUSTOMER_TYPE2 d
SET
    EXPIRY_DATE =
        CASE
            WHEN u.CUSTOMER_ID = 101 THEN '2026-03-31'
            WHEN u.CUSTOMER_ID = 103 THEN '2026-04-04'
            WHEN u.CUSTOMER_ID = 104 THEN '2026-04-09'
        END,
    IS_CURRENT = FALSE
FROM CUSTOMER_UPDATES u
WHERE d.CUSTOMER_ID = u.CUSTOMER_ID
  AND d.IS_CURRENT = TRUE;


-- Check expired records

SELECT *
FROM DIM_CUSTOMER_TYPE2
WHERE IS_CURRENT = FALSE
ORDER BY CUSTOMER_ID;


-- ============================================================
-- TASK 10 — STEP 2
-- INSERT NEW VERSIONS
-- ============================================================

INSERT INTO DIM_CUSTOMER_TYPE2
(
    CUSTOMER_KEY,
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    SEGMENT,
    EFFECTIVE_DATE,
    EXPIRY_DATE,
    IS_CURRENT
)
SELECT
    ROW_NUMBER() OVER (ORDER BY u.CUSTOMER_ID)
        + (
            SELECT COALESCE(MAX(CUSTOMER_KEY), 0)
            FROM DIM_CUSTOMER_TYPE2
        ),
    u.CUSTOMER_ID,
    u.CUSTOMER_NAME,
    u.CITY,
    u.STATE,
    u.MEMBERSHIP,
    u.SEGMENT,

    CASE
        WHEN u.CUSTOMER_ID = 101 THEN '2026-04-01'
        WHEN u.CUSTOMER_ID = 103 THEN '2026-04-05'
        WHEN u.CUSTOMER_ID = 104 THEN '2026-04-10'
    END,

    '9999-12-31',
    TRUE

FROM CUSTOMER_UPDATES u;


-- ============================================================
-- TASK 11, 12, 13
-- CHECK EACH CUSTOMER'S HISTORY
-- ============================================================


-- Customer 101

SELECT
    CUSTOMER_ID,
    CITY,
    MEMBERSHIP,
    EFFECTIVE_DATE,
    EXPIRY_DATE,
    IS_CURRENT
FROM DIM_CUSTOMER_TYPE2
WHERE CUSTOMER_ID = 101
ORDER BY EFFECTIVE_DATE;


-- Expected:
--
-- 101 | Hyderabad | Silver | 2026-01-01 | 2026-03-31 | FALSE
-- 101 | Bengaluru | Gold   | 2026-04-01 | 9999-12-31 | TRUE


-- Customer 103

SELECT
    CUSTOMER_ID,
    CITY,
    MEMBERSHIP,
    EFFECTIVE_DATE,
    EXPIRY_DATE,
    IS_CURRENT
FROM DIM_CUSTOMER_TYPE2
WHERE CUSTOMER_ID = 103
ORDER BY EFFECTIVE_DATE;


-- Expected:
--
-- 103 | Vijayawada | Silver | 2026-01-01 | 2026-04-04 | FALSE
-- 103 | Chennai    | Gold   | 2026-04-05 | 9999-12-31 | TRUE


-- Customer 104

SELECT
    CUSTOMER_ID,
    CITY,
    MEMBERSHIP,
    EFFECTIVE_DATE,
    EXPIRY_DATE,
    IS_CURRENT
FROM DIM_CUSTOMER_TYPE2
WHERE CUSTOMER_ID = 104
ORDER BY EFFECTIVE_DATE;


-- Expected:
--
-- 104 | Hyderabad | Gold     | 2026-01-01 | 2026-04-09 | FALSE
-- 104 | Hyderabad | Platinum | 2026-04-10 | 9999-12-31 | TRUE


-- ============================================================
-- TASK 14 — DISPLAY COMPLETE TYPE 2 HISTORY
-- ============================================================

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    SEGMENT,
    EFFECTIVE_DATE,
    EXPIRY_DATE,
    IS_CURRENT
FROM DIM_CUSTOMER_TYPE2
ORDER BY CUSTOMER_ID, EFFECTIVE_DATE;


-- Expected total:
-- 101 → 2 records
-- 102 → 1 record
-- 103 → 2 records
-- 104 → 2 records
-- 105 → 1 record
--
-- TOTAL = 8


-- ============================================================
-- TASK 15 — DISPLAY CURRENT CUSTOMER RECORDS
-- ============================================================

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    SEGMENT
FROM DIM_CUSTOMER_TYPE2
WHERE IS_CURRENT = TRUE
ORDER BY CUSTOMER_ID;


-- Expected:
--
-- 101 Amit Sharma  Bengaluru   Karnataka      Gold      Premium
-- 102 Priya Reddy  Warangal    Telangana      Gold      Premium
-- 103 Rahul Verma  Chennai     Tamil Nadu     Gold      Premium
-- 104 Neha Patel   Hyderabad   Telangana      Platinum  Premium
-- 105 Arjun Gupta  Nagpur      Maharashtra    Bronze    Regular


-- ============================================================
-- TASK 16 — HISTORICAL CUSTOMER ANALYSIS
-- ============================================================

-- Question:
-- What was Customer 101's membership on March 15, 2026?

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    MEMBERSHIP,
    CITY,
    EFFECTIVE_DATE,
    EXPIRY_DATE
FROM DIM_CUSTOMER_TYPE2
WHERE CUSTOMER_ID = 101
  AND '2026-03-15' BETWEEN EFFECTIVE_DATE AND EXPIRY_DATE;


-- Expected:
--
-- 101 | Amit Sharma | Silver | Hyderabad
--     | 2026-01-01 | 2026-03-31


-- ============================================================
-- GENERAL POINT-IN-TIME QUERY
-- ============================================================

-- You can replace the date below with ANY date.

SELECT
    CUSTOMER_ID,
    CUSTOMER_NAME,
    CITY,
    STATE,
    MEMBERSHIP,
    SEGMENT
FROM DIM_CUSTOMER_TYPE2
WHERE CUSTOMER_ID = 101
  AND '2026-03-15' BETWEEN EFFECTIVE_DATE AND EXPIRY_DATE;


-- ============================================================
-- TASK 17 — COMPARE TYPE 1 VS TYPE 2
-- ============================================================

-- Type 1

SELECT
    'SCD TYPE 1' AS SCD_TYPE,
    'Old Value → Overwritten' AS OLD_VALUE,
    'History → Not Preserved' AS HISTORY,
    'New Row → No' AS NEW_ROW;


-- Type 2

SELECT
    'SCD TYPE 2' AS SCD_TYPE,
    'Old Value → Preserved' AS OLD_VALUE,
    'History → Preserved' AS HISTORY,
    'New Row → Yes' AS NEW_ROW;


-- ============================================================
-- SIDE-BY-SIDE RECORD COUNT
-- ============================================================

SELECT
    (SELECT COUNT(*)
     FROM DIM_CUSTOMER_TYPE1) AS TYPE1_RECORD_COUNT,

    (SELECT COUNT(*)
     FROM DIM_CUSTOMER_TYPE2) AS TYPE2_RECORD_COUNT;


-- Expected:
--
-- TYPE1_RECORD_COUNT = 5
-- TYPE2_RECORD_COUNT = 8
List @Customer_Stage
-- ============================================================
-- TASK 18 — FINAL VALIDATION
-- ============================================================

-- Type 1 record count

SELECT COUNT(*) AS SCD_TYPE1_RECORD_COUNT
FROM DIM_CUSTOMER_TYPE1;


-- Expected = 5


-- Type 2 total record count

SELECT COUNT(*) AS SCD_TYPE2_RECORD_COUNT
FROM DIM_CUSTOMER_TYPE2;


-- Expected = 8


-- Type 2 current records

SELECT COUNT(*) AS SCD_TYPE2_CURRENT_RECORD_COUNT
FROM DIM_CUSTOMER_TYPE2
WHERE IS_CURRENT = TRUE;


-- Expected = 5


-- Type 2 historical records

SELECT COUNT(*) AS SCD_TYPE2_HISTORICAL_RECORD_COUNT
FROM DIM_CUSTOMER_TYPE2
WHERE IS_CURRENT = FALSE;







