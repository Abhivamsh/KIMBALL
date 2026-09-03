
-- TASK 1
-- DATABASE + SCHEMA


USE WAREHOUSE COMPUTE_WH;

CREATE OR REPLACE DATABASE RETAIL_SCHEMAS_DW;

USE DATABASE RETAIL_SCHEMAS_DW;

CREATE OR REPLACE SCHEMA SCHEMA_COMPARISON;

USE SCHEMA SCHEMA_COMPARISON;


-- TASK 2
-- STAGE + FILE FORMAT

CREATE OR REPLACE STAGE RETAIL_STAGE;

LIST @RETAIL_STAGE;


CREATE OR REPLACE FILE FORMAT RETAIL_CSV_FORMAT
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_DELIMITER = ','
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_BLANK_LINES = TRUE
    TRIM_SPACE = TRUE
    NULL_IF = ('NULL', 'null', '');



-- STAGING TABLE 1
-- REGIONS + STORES

CREATE OR REPLACE TABLE STG_REGIONS_STORES (
    STORE_ID NUMBER,
    STORE_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    REGION_NAME VARCHAR(50),
    REGIONAL_MANAGER VARCHAR(100)
);



-- STAGING TABLE 2
-- PRODUCT HIERARCHY

CREATE OR REPLACE TABLE STG_PRODUCT_HIERARCHY (
    PRODUCT_ID NUMBER,
    PRODUCT_NAME VARCHAR(100),
    SUBCATEGORY_NAME VARCHAR(50),
    CATEGORY_NAME VARCHAR(50),
    UNIT_PRICE NUMBER(10,2)
);


-- STAGING TABLE 3
-- CUSTOMERS

CREATE OR REPLACE TABLE STG_CUSTOMERS (
    CUSTOMER_ID NUMBER,
    CUSTOMER_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50)
);


-- STAGING TABLE 4
-- SALES TRANSACTIONS

CREATE OR REPLACE TABLE STG_SALES_TRANSACTIONS (
    TRANSACTION_ID VARCHAR(50),
    TRANSACTION_DATE DATE,
    CUSTOMER_ID NUMBER,
    STORE_ID NUMBER,
    PRODUCT_ID NUMBER,
    QUANTITY NUMBER,
    UNIT_PRICE NUMBER(10,2)
);


-- ============================================================
-- LOAD CSV FILES
-- ============================================================

COPY INTO STG_REGIONS_STORES
FROM @RETAIL_STAGE/regions_and_stores.csv
FILE_FORMAT = RETAIL_CSV_FORMAT
ON_ERROR = 'ABORT_STATEMENT'
FORCE = TRUE;


COPY INTO STG_PRODUCT_HIERARCHY
FROM @RETAIL_STAGE/product_hierarchy.csv
FILE_FORMAT = RETAIL_CSV_FORMAT
ON_ERROR = 'ABORT_STATEMENT'
FORCE = TRUE;


COPY INTO STG_CUSTOMERS
FROM @RETAIL_STAGE/customers.csv
FILE_FORMAT = RETAIL_CSV_FORMAT
ON_ERROR = 'ABORT_STATEMENT'
FORCE = TRUE;


COPY INTO STG_SALES_TRANSACTIONS
FROM @RETAIL_STAGE/sales_transactions.csv
FILE_FORMAT = RETAIL_CSV_FORMAT
ON_ERROR = 'ABORT_STATEMENT'
FORCE = TRUE;


-- ============================================================
-- VALIDATE STAGING
-- ============================================================

SELECT
    'STG_REGIONS_STORES' AS TABLE_NAME,
    COUNT(*) AS RECORD_COUNT
FROM STG_REGIONS_STORES

UNION ALL

SELECT
    'STG_PRODUCT_HIERARCHY',
    COUNT(*)
FROM STG_PRODUCT_HIERARCHY

UNION ALL

SELECT
    'STG_CUSTOMERS',
    COUNT(*)
FROM STG_CUSTOMERS

UNION ALL

SELECT
    'STG_SALES_TRANSACTIONS',
    COUNT(*)
FROM STG_SALES_TRANSACTIONS;



-- ============================================================
-- STAR SCHEMA
-- ============================================================


-- ============================================================
-- TASK 2
-- STAR_DIM_STORE
-- ============================================================

CREATE OR REPLACE TABLE STAR_DIM_STORE (
    STORE_KEY NUMBER AUTOINCREMENT PRIMARY KEY,
    STORE_ID NUMBER,
    STORE_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    REGION_NAME VARCHAR(50),
    REGIONAL_MANAGER VARCHAR(100)
);


-- ============================================================
-- TASK 3
-- STAR_DIM_PRODUCT
-- ============================================================

CREATE OR REPLACE TABLE STAR_DIM_PRODUCT (
    PRODUCT_KEY NUMBER AUTOINCREMENT PRIMARY KEY,
    PRODUCT_ID NUMBER,
    PRODUCT_NAME VARCHAR(100),
    SUBCATEGORY_NAME VARCHAR(50),
    CATEGORY_NAME VARCHAR(50),
    UNIT_PRICE NUMBER(10,2)
);


-- ============================================================
-- TASK 4
-- LOAD STAR STORE DIMENSION
-- ============================================================

INSERT INTO STAR_DIM_STORE (
    STORE_ID,
    STORE_NAME,
    CITY,
    STATE,
    REGION_NAME,
    REGIONAL_MANAGER
)
SELECT
    STORE_ID,
    STORE_NAME,
    CITY,
    STATE,
    REGION_NAME,
    REGIONAL_MANAGER
FROM STG_REGIONS_STORES;


-- ============================================================
-- LOAD STAR PRODUCT DIMENSION
-- ============================================================

INSERT INTO STAR_DIM_PRODUCT (
    PRODUCT_ID,
    PRODUCT_NAME,
    SUBCATEGORY_NAME,
    CATEGORY_NAME,
    UNIT_PRICE
)
SELECT
    PRODUCT_ID,
    PRODUCT_NAME,
    SUBCATEGORY_NAME,
    CATEGORY_NAME,
    UNIT_PRICE
FROM STG_PRODUCT_HIERARCHY;


-- ============================================================
-- CHECK STAR DIMENSIONS
-- ============================================================

SELECT *
FROM STAR_DIM_STORE
ORDER BY STORE_ID;


SELECT *
FROM STAR_DIM_PRODUCT
ORDER BY PRODUCT_ID;



-- ============================================================
-- TASK 4
-- STAR FACT TABLE
-- ============================================================

CREATE OR REPLACE TABLE STAR_FACT_SALES (
    SALES_KEY NUMBER AUTOINCREMENT PRIMARY KEY,
    TRANSACTION_ID VARCHAR(50),
    TRANSACTION_DATE DATE,
    CUSTOMER_ID NUMBER,
    STORE_KEY NUMBER,
    PRODUCT_KEY NUMBER,
    QUANTITY NUMBER,
    TOTAL_AMOUNT NUMBER(12,2),

    FOREIGN KEY (STORE_KEY)
        REFERENCES STAR_DIM_STORE(STORE_KEY),

    FOREIGN KEY (PRODUCT_KEY)
        REFERENCES STAR_DIM_PRODUCT(PRODUCT_KEY)
);


-- ============================================================
-- TASK 5
-- LOAD STAR FACT
-- DYNAMIC SURROGATE KEY LOOKUP
-- ============================================================

INSERT INTO STAR_FACT_SALES (
    TRANSACTION_ID,
    TRANSACTION_DATE,
    CUSTOMER_ID,
    STORE_KEY,
    PRODUCT_KEY,
    QUANTITY,
    TOTAL_AMOUNT
)
SELECT
    t.TRANSACTION_ID,
    t.TRANSACTION_DATE,
    t.CUSTOMER_ID,

    s.STORE_KEY,

    p.PRODUCT_KEY,

    t.QUANTITY,

    t.QUANTITY * t.UNIT_PRICE

FROM STG_SALES_TRANSACTIONS t

JOIN STAR_DIM_STORE s
    ON t.STORE_ID = s.STORE_ID

JOIN STAR_DIM_PRODUCT p
    ON t.PRODUCT_ID = p.PRODUCT_ID;


-- ============================================================
-- CHECK STAR FACT
-- ============================================================

SELECT *
FROM STAR_FACT_SALES
ORDER BY TRANSACTION_DATE;



-- ============================================================
-- SNOWFLAKE SCHEMA
-- ============================================================


-- ============================================================
-- TASK 6
-- REGION DIMENSION
-- ============================================================

CREATE OR REPLACE TABLE SNOW_DIM_REGION (
    REGION_KEY NUMBER AUTOINCREMENT PRIMARY KEY,
    REGION_NAME VARCHAR(50),
    REGIONAL_MANAGER VARCHAR(100)
);


-- ============================================================
-- STORE DIMENSION
-- ============================================================

CREATE OR REPLACE TABLE SNOW_DIM_STORE (
    STORE_KEY NUMBER AUTOINCREMENT PRIMARY KEY,
    STORE_ID NUMBER,
    STORE_NAME VARCHAR(100),
    CITY VARCHAR(50),
    STATE VARCHAR(50),
    REGION_KEY NUMBER,

    FOREIGN KEY (REGION_KEY)
        REFERENCES SNOW_DIM_REGION(REGION_KEY)
);



-- ============================================================
-- TASK 7
-- CATEGORY DIMENSION
-- ============================================================

CREATE OR REPLACE TABLE SNOW_DIM_CATEGORY (
    CATEGORY_KEY NUMBER AUTOINCREMENT PRIMARY KEY,
    CATEGORY_NAME VARCHAR(50)
);


-- ============================================================
-- SUBCATEGORY DIMENSION
-- ============================================================

CREATE OR REPLACE TABLE SNOW_DIM_SUBCATEGORY (
    SUBCATEGORY_KEY NUMBER AUTOINCREMENT PRIMARY KEY,
    SUBCATEGORY_NAME VARCHAR(50),
    CATEGORY_KEY NUMBER,

    FOREIGN KEY (CATEGORY_KEY)
        REFERENCES SNOW_DIM_CATEGORY(CATEGORY_KEY)
);


-- ============================================================
-- PRODUCT DIMENSION
-- ============================================================

CREATE OR REPLACE TABLE SNOW_DIM_PRODUCT (
    PRODUCT_KEY NUMBER AUTOINCREMENT PRIMARY KEY,
    PRODUCT_ID NUMBER,
    PRODUCT_NAME VARCHAR(100),
    UNIT_PRICE NUMBER(10,2),
    SUBCATEGORY_KEY NUMBER,

    FOREIGN KEY (SUBCATEGORY_KEY)
        REFERENCES SNOW_DIM_SUBCATEGORY(SUBCATEGORY_KEY)
);



-- ============================================================
-- TASK 8
-- LOAD SNOW_DIM_REGION
-- ============================================================

INSERT INTO SNOW_DIM_REGION (
    REGION_NAME,
    REGIONAL_MANAGER
)
SELECT DISTINCT
    REGION_NAME,
    REGIONAL_MANAGER
FROM STG_REGIONS_STORES
ORDER BY REGION_NAME;


-- ============================================================
-- LOAD SNOW_DIM_STORE
-- ============================================================

INSERT INTO SNOW_DIM_STORE (
    STORE_ID,
    STORE_NAME,
    CITY,
    STATE,
    REGION_KEY
)
SELECT
    s.STORE_ID,
    s.STORE_NAME,
    s.CITY,
    s.STATE,
    r.REGION_KEY

FROM STG_REGIONS_STORES s

JOIN SNOW_DIM_REGION r
    ON s.REGION_NAME = r.REGION_NAME

   AND s.REGIONAL_MANAGER = r.REGIONAL_MANAGER;



-- ============================================================
-- LOAD SNOW_DIM_CATEGORY
-- ============================================================

INSERT INTO SNOW_DIM_CATEGORY (
    CATEGORY_NAME
)
SELECT DISTINCT
    CATEGORY_NAME
FROM STG_PRODUCT_HIERARCHY
ORDER BY CATEGORY_NAME;



-- ============================================================
-- LOAD SNOW_DIM_SUBCATEGORY
-- ============================================================

INSERT INTO SNOW_DIM_SUBCATEGORY (
    SUBCATEGORY_NAME,
    CATEGORY_KEY
)
SELECT DISTINCT
    p.SUBCATEGORY_NAME,
    c.CATEGORY_KEY

FROM STG_PRODUCT_HIERARCHY p

JOIN SNOW_DIM_CATEGORY c
    ON p.CATEGORY_NAME = c.CATEGORY_NAME;



-- ============================================================
-- LOAD SNOW_DIM_PRODUCT
-- ============================================================

INSERT INTO SNOW_DIM_PRODUCT (
    PRODUCT_ID,
    PRODUCT_NAME,
    UNIT_PRICE,
    SUBCATEGORY_KEY
)
SELECT
    p.PRODUCT_ID,
    p.PRODUCT_NAME,
    p.UNIT_PRICE,
    sc.SUBCATEGORY_KEY

FROM STG_PRODUCT_HIERARCHY p

JOIN SNOW_DIM_SUBCATEGORY sc
    ON p.SUBCATEGORY_NAME = sc.SUBCATEGORY_NAME

JOIN SNOW_DIM_CATEGORY c
    ON sc.CATEGORY_KEY = c.CATEGORY_KEY

   AND p.CATEGORY_NAME = c.CATEGORY_NAME;



-- ============================================================
-- CHECK SNOWFLAKE DIMENSIONS
-- ============================================================

SELECT *
FROM SNOW_DIM_REGION
ORDER BY REGION_KEY;


SELECT *
FROM SNOW_DIM_STORE
ORDER BY STORE_ID;


SELECT *
FROM SNOW_DIM_CATEGORY
ORDER BY CATEGORY_KEY;


SELECT *
FROM SNOW_DIM_SUBCATEGORY
ORDER BY SUBCATEGORY_KEY;


SELECT *
FROM SNOW_DIM_PRODUCT
ORDER BY PRODUCT_ID;



-- ============================================================
-- TASK 9
-- SNOWFLAKE FACT TABLE
-- ============================================================

CREATE OR REPLACE TABLE SNOW_FACT_SALES (
    SALES_KEY NUMBER AUTOINCREMENT PRIMARY KEY,

    TRANSACTION_ID VARCHAR(50),

    TRANSACTION_DATE DATE,

    CUSTOMER_ID NUMBER,

    STORE_KEY NUMBER,

    PRODUCT_KEY NUMBER,

    QUANTITY NUMBER,

    TOTAL_AMOUNT NUMBER(12,2),

    FOREIGN KEY (STORE_KEY)
        REFERENCES SNOW_DIM_STORE(STORE_KEY),

    FOREIGN KEY (PRODUCT_KEY)
        REFERENCES SNOW_DIM_PRODUCT(PRODUCT_KEY)
);



-- ============================================================
-- LOAD SNOWFLAKE FACT
-- ============================================================

INSERT INTO SNOW_FACT_SALES (
    TRANSACTION_ID,
    TRANSACTION_DATE,
    CUSTOMER_ID,
    STORE_KEY,
    PRODUCT_KEY,
    QUANTITY,
    TOTAL_AMOUNT
)
SELECT
    t.TRANSACTION_ID,

    t.TRANSACTION_DATE,

    t.CUSTOMER_ID,

    s.STORE_KEY,

    p.PRODUCT_KEY,

    t.QUANTITY,

    t.QUANTITY * t.UNIT_PRICE

FROM STG_SALES_TRANSACTIONS t

JOIN SNOW_DIM_STORE s
    ON t.STORE_ID = s.STORE_ID

JOIN SNOW_DIM_PRODUCT p
    ON t.PRODUCT_ID = p.PRODUCT_ID;



-- ============================================================
-- CHECK SNOWFLAKE FACT
-- ============================================================

SELECT *
FROM SNOW_FACT_SALES
ORDER BY TRANSACTION_DATE;



-- ============================================================
-- TASK 10
-- STAR SCHEMA ANALYTICS
--
-- Revenue by Region + Category
-- ============================================================

SELECT

    s.REGION_NAME,

    p.CATEGORY_NAME,

    SUM(f.TOTAL_AMOUNT) AS TOTAL_REVENUE

FROM STAR_FACT_SALES f

JOIN STAR_DIM_STORE s
    ON f.STORE_KEY = s.STORE_KEY

JOIN STAR_DIM_PRODUCT p
    ON f.PRODUCT_KEY = p.PRODUCT_KEY

GROUP BY

    s.REGION_NAME,

    p.CATEGORY_NAME

ORDER BY

    s.REGION_NAME,

    p.CATEGORY_NAME;






-- ============================================================
-- TASK 11
-- SNOWFLAKE SCHEMA ANALYTICS
--
-- Same business question
-- But with normalized hierarchy joins
-- ============================================================

SELECT

    r.REGION_NAME,

    c.CATEGORY_NAME,

    SUM(f.TOTAL_AMOUNT) AS TOTAL_REVENUE

FROM SNOW_FACT_SALES f

JOIN SNOW_DIM_STORE s
    ON f.STORE_KEY = s.STORE_KEY

JOIN SNOW_DIM_REGION r
    ON s.REGION_KEY = r.REGION_KEY

JOIN SNOW_DIM_PRODUCT p
    ON f.PRODUCT_KEY = p.PRODUCT_KEY

JOIN SNOW_DIM_SUBCATEGORY sc
    ON p.SUBCATEGORY_KEY = sc.SUBCATEGORY_KEY

JOIN SNOW_DIM_CATEGORY c
    ON sc.CATEGORY_KEY = c.CATEGORY_KEY

GROUP BY

    r.REGION_NAME,

    c.CATEGORY_NAME

ORDER BY

    r.REGION_NAME,

    c.CATEGORY_NAME;





-- ============================================================
-- TASK 12
-- STAR VS SNOWFLAKE COMPARISON
-- ============================================================

SELECT
    'Dimension Normalization Level' AS METRIC,
    'Denormalized (Flat)' AS STAR_SCHEMA,
    'Normalized (Hierarchical)' AS SNOWFLAKE_SCHEMA

UNION ALL

SELECT
    'Total Dimension Tables',
    '2 Tables',
    '5 Tables'

UNION ALL

SELECT
    'Joins for Category Revenue',
    '2 Joins',
    '4 Joins'

UNION ALL

SELECT
    'Data Redundancy',
    'Higher',
    'Lower'

UNION ALL

SELECT
    'Query Simplicity',
    'High',
    'Lower';



-- ============================================================
-- TASK 13
-- REGIONAL MANAGER SALES PERFORMANCE
-- STAR SCHEMA
-- ============================================================

SELECT

    s.REGIONAL_MANAGER,

    SUM(f.QUANTITY) AS TOTAL_ITEMS_SOLD,

    SUM(f.TOTAL_AMOUNT) AS TOTAL_SALES_AMOUNT

FROM STAR_FACT_SALES f

JOIN STAR_DIM_STORE s
    ON f.STORE_KEY = s.STORE_KEY

GROUP BY

    s.REGIONAL_MANAGER

ORDER BY

    s.REGIONAL_MANAGER;





-- ============================================================
-- TASK 14
-- FULL WAREHOUSE AUDIT
-- ============================================================

SELECT

    'Star Schema' AS SCHEMA_TYPE,

    'STAR_DIM_STORE' AS TABLE_NAME,

    COUNT(*) AS RECORD_COUNT

FROM STAR_DIM_STORE


UNION ALL


SELECT

    'Star Schema',

    'STAR_DIM_PRODUCT',

    COUNT(*)

FROM STAR_DIM_PRODUCT


UNION ALL


SELECT

    'Star Schema',

    'STAR_FACT_SALES',

    COUNT(*)

FROM STAR_FACT_SALES


UNION ALL


SELECT

    'Snowflake Schema',

    'SNOW_DIM_REGION',

    COUNT(*)

FROM SNOW_DIM_REGION


UNION ALL


SELECT

    'Snowflake Schema',

    'SNOW_DIM_STORE',

    COUNT(*)

FROM SNOW_DIM_STORE


UNION ALL


SELECT

    'Snowflake Schema',

    'SNOW_DIM_CATEGORY',

    COUNT(*)

FROM SNOW_DIM_CATEGORY


UNION ALL


SELECT

    'Snowflake Schema',

    'SNOW_DIM_SUBCATEGORY',

    COUNT(*)

FROM SNOW_DIM_SUBCATEGORY


UNION ALL


SELECT

    'Snowflake Schema',

    'SNOW_DIM_PRODUCT',

    COUNT(*)

FROM SNOW_DIM_PRODUCT


UNION ALL


SELECT

    'Snowflake Schema',

    'SNOW_FACT_SALES',

    COUNT(*)

FROM SNOW_FACT_SALES;