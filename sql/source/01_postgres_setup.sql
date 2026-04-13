-- =============================================================================
-- NorthRoute Logistics — Source Database (PostgreSQL)
-- Simulates an on-premise ERP. Data is intentionally messy:
--   - Duplicate doc_entry values (system glitch re-submissions)
--   - CANCELLED orders
--   - Negative tonnage (weigh bridge errors)
--   - NULL tonnage (not recorded at weigh bridge)
--   - Inconsistent status casing ('DELIVERED', 'Delivered', 'delivered')
-- This is the "before" — the point of the demo is watching it get cleaned.
-- =============================================================================

DROP DATABASE IF EXISTS northroute_erp;
CREATE DATABASE northroute_erp;
\connect northroute_erp

CREATE SCHEMA IF NOT EXISTS erp;

-- =============================================================================
-- WAREHOUSES
-- =============================================================================
DROP TABLE IF EXISTS erp.warehouses CASCADE;
CREATE TABLE erp.warehouses (
    warehouse_id    VARCHAR(10)   PRIMARY KEY,
    warehouse_name  VARCHAR(100)  NOT NULL,
    city            VARCHAR(50)   NOT NULL,
    region          VARCHAR(50)   NOT NULL,
    capacity_tonnes DECIMAL(10,2) NOT NULL
);

INSERT INTO erp.warehouses VALUES
    ('WH01', 'Manchester North', 'Manchester', 'North West',  5000.00),
    ('WH02', 'Leeds Central',    'Leeds',       'Yorkshire',   4200.00),
    ('WH03', 'Birmingham Hub',   'Birmingham',  'Midlands',    6100.00),
    ('WH04', 'Bristol Docks',    'Bristol',     'South West',  3800.00),
    ('WH05', 'Edinburgh Park',   'Edinburgh',   'Scotland',    2900.00);

-- =============================================================================
-- CUSTOMERS
-- =============================================================================
DROP TABLE IF EXISTS erp.customers CASCADE;
CREATE TABLE erp.customers (
    customer_id    VARCHAR(10)  PRIMARY KEY,
    company_name   VARCHAR(100) NOT NULL,
    contact_name   VARCHAR(100),
    city           VARCHAR(50)  NOT NULL,
    account_status VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE'
);

INSERT INTO erp.customers VALUES
    ('CUST001', 'Apex Manufacturing Ltd',  'Sarah Booth',  'Sheffield',  'ACTIVE'),
    ('CUST002', 'Brennan & Sons Builders', 'Mike Brennan', 'Liverpool',  'ACTIVE'),
    ('CUST003', 'Clearwater Retail PLC',   'Jo Patel',     'Bristol',    'ACTIVE'),
    ('CUST004', 'Denton Industrial',       'Chris Denton', 'Coventry',   'ACTIVE'),
    ('CUST005', 'Easton Food Group',       'Rachel Easton','Glasgow',    'ACTIVE'),
    ('CUST006', 'Fletcher Aggregates',     'Tom Fletcher', 'Leeds',      'ACTIVE'),
    ('CUST007', 'Greystone Properties',    NULL,           'Edinburgh',  'INACTIVE'),
    ('CUST008', 'Hartley Waste Solutions', 'Ben Hartley',  'Birmingham', 'ACTIVE');

-- =============================================================================
-- DELIVERY ORDERS — the main fact table in the source
-- =============================================================================
DROP TABLE IF EXISTS erp.delivery_orders CASCADE;
CREATE TABLE erp.delivery_orders (
    order_id         SERIAL        PRIMARY KEY,
    doc_entry        VARCHAR(20)   NOT NULL,
    order_date       DATE          NOT NULL,
    delivery_date    DATE,
    warehouse_id     VARCHAR(10)   REFERENCES erp.warehouses(warehouse_id),
    customer_id      VARCHAR(10)   REFERENCES erp.customers(customer_id),
    product_category VARCHAR(50)   NOT NULL,
    quantity_tonnes  DECIMAL(10,3),
    unit_price_gbp   DECIMAL(10,2),
    status           VARCHAR(30)   NOT NULL,
    driver_name      VARCHAR(100),
    notes            TEXT,
    created_at       TIMESTAMP     NOT NULL DEFAULT NOW()
);

INSERT INTO erp.delivery_orders
    (doc_entry, order_date, delivery_date, warehouse_id, customer_id,
     product_category, quantity_tonnes, unit_price_gbp, status, driver_name, notes)
VALUES
-- January 2024
('DOC-1001','2024-01-03','2024-01-04','WH01','CUST001','Aggregates',  24.500, 82.00,'DELIVERED', 'Dave Okafor', NULL),
('DOC-1002','2024-01-03','2024-01-04','WH02','CUST002','Timber',      18.200, 95.50,'DELIVERED', 'Sue Hartley', NULL),
('DOC-1003','2024-01-05','2024-01-06','WH03','CUST003','Steel',       31.000,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1004','2024-01-05','2024-01-07','WH01','CUST004','Aggregates',  12.750, 82.00,'DELIVERED', 'Dave Okafor', NULL),
('DOC-1005','2024-01-08','2024-01-09','WH04','CUST003','Chemicals',    8.000,210.00,'DELIVERED', 'Anna Moss',   NULL),
('DOC-1006','2024-01-08','2024-01-09','WH02','CUST006','Timber',      22.000, 95.50,'Delivered', 'Sue Hartley', NULL),  -- inconsistent casing
('DOC-1007','2024-01-10','2024-01-11','WH05','CUST005','Food Grade',  15.500,175.00,'DELIVERED', 'Ian Reid',    NULL),
('DOC-1008','2024-01-10', NULL,       'WH03','CUST008','Steel',       28.000,142.00,'CANCELLED', NULL,          'Customer cancelled — stock issue'),
('DOC-1009','2024-01-12','2024-01-13','WH01','CUST002','Aggregates',  19.250, 82.00,'DELIVERED', 'Dave Okafor', NULL),
('DOC-1010','2024-01-12','2024-01-13','WH02','CUST001','Timber',      14.000, 95.50,'DELIVERED', 'Sue Hartley', NULL),
-- DUPLICATE: DOC-1003 re-submitted by mistake
('DOC-1003','2024-01-05','2024-01-06','WH03','CUST003','Steel',       31.000,142.00,'DELIVERED', 'Paul Singh',  'DUPLICATE — re-submitted in error'),
('DOC-1011','2024-01-15','2024-01-16','WH04','CUST007','Aggregates',   9.500, 82.00,'DELIVERED', 'Anna Moss',   NULL),
('DOC-1012','2024-01-15','2024-01-16','WH01','CUST004','Steel',       35.200,142.00,'DELIVERED', 'Dave Okafor', NULL),
('DOC-1013','2024-01-17','2024-01-18','WH03','CUST008','Chemicals',   11.000,210.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1014','2024-01-17','2024-01-18','WH02','CUST006','Timber',      25.500, 95.50,'DELIVERED', 'Sue Hartley', NULL),
('DOC-1015','2024-01-19','2024-01-20','WH05','CUST005','Food Grade',  20.000,175.00,'DELIVERED', 'Ian Reid',    NULL),
('DOC-1016','2024-01-19', NULL,       'WH01','CUST001','Aggregates',  16.000, 82.00,'IN TRANSIT','Dave Okafor', NULL),
('DOC-1017','2024-01-22','2024-01-23','WH03','CUST003','Steel',       42.000,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1018','2024-01-22','2024-01-23','WH04','CUST002','Chemicals',    6.500,210.00,'delivered', 'Anna Moss',   NULL),  -- lowercase
('DOC-1019','2024-01-24','2024-01-25','WH02','CUST001','Timber',      17.750, 95.50,'DELIVERED', 'Sue Hartley', NULL),
('DOC-1020','2024-01-24','2024-01-25','WH01','CUST004','Aggregates',  23.000, 82.00,'DELIVERED', 'Dave Okafor', NULL),
('DOC-1021','2024-01-26','2024-01-27','WH05','CUST005','Food Grade',   NULL, 175.00,'DELIVERED', 'Ian Reid',    'Tonnage not recorded at weigh bridge'),  -- NULL tonnage
('DOC-1022','2024-01-26','2024-01-27','WH03','CUST008','Steel',       38.500,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1023','2024-01-29','2024-01-30','WH02','CUST006','Timber',      21.000, 95.50,'DELIVERED', 'Sue Hartley', NULL),
('DOC-1024','2024-01-29','2024-01-30','WH04','CUST003','Chemicals',   10.000,210.00,'DELIVERED', 'Anna Moss',   NULL),
('DOC-1025','2024-01-31','2024-02-01','WH01','CUST002','Aggregates',  28.000, 82.00,'DELIVERED', 'Dave Okafor', NULL),
-- February 2024
('DOC-1026','2024-02-01','2024-02-02','WH03','CUST001','Steel',       33.000,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1027','2024-02-01','2024-02-02','WH02','CUST004','Timber',      19.500, 95.50,'DELIVERED', 'Sue Hartley', NULL),
('DOC-1028','2024-02-05','2024-02-06','WH01','CUST001','Aggregates',  -4.000, 82.00,'DELIVERED', 'Dave Okafor', 'NEGATIVE — weigh bridge error, return journey logged'),  -- NEGATIVE
('DOC-1029','2024-02-05','2024-02-06','WH05','CUST005','Food Grade',  22.500,175.00,'DELIVERED', 'Ian Reid',    NULL),
('DOC-1030','2024-02-07','2024-02-08','WH04','CUST002','Chemicals',    7.000,210.00,'DELIVERED', 'Anna Moss',   NULL),
('DOC-1031','2024-02-07','2024-02-08','WH03','CUST008','Steel',       29.500,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1032','2024-02-09','2024-02-10','WH02','CUST006','Timber',      16.000, 95.50,'DELIVERED', 'Sue Hartley', NULL),
('DOC-1033','2024-02-09', NULL,       'WH01','CUST004','Aggregates',  20.000, 82.00,'CANCELLED', NULL,          'Route cancelled — adverse weather'),
('DOC-1034','2024-02-12','2024-02-13','WH03','CUST003','Steel',       45.000,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1035','2024-02-12','2024-02-13','WH01','CUST002','Aggregates',  26.750, 82.00,'DELIVERED', 'Dave Okafor', NULL),
-- DUPLICATE: DOC-1034
('DOC-1034','2024-02-12','2024-02-13','WH03','CUST003','Steel',       45.000,142.00,'DELIVERED', 'Paul Singh',  'DUPLICATE — system error'),
('DOC-1036','2024-02-14','2024-02-15','WH05','CUST005','Food Grade',  18.000,175.00,'DELIVERED', 'Ian Reid',    NULL),
('DOC-1037','2024-02-14','2024-02-15','WH04','CUST007','Chemicals',    5.500,210.00,'DELIVERED', 'Anna Moss',   NULL),
('DOC-1038','2024-02-16','2024-02-17','WH02','CUST001','Timber',      23.000, 95.50,'DELIVERED', 'Sue Hartley', NULL),
('DOC-1039','2024-02-16','2024-02-17','WH03','CUST008','Steel',       31.000,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1040','2024-02-19','2024-02-20','WH01','CUST004','Aggregates',  14.500, 82.00,'DELIVERED', 'Dave Okafor', NULL),
('DOC-1041','2024-02-19','2024-02-20','WH02','CUST006','Timber',      27.000, 95.50,'Delivered', 'Sue Hartley', NULL),
('DOC-1042','2024-02-21','2024-02-22','WH05','CUST005','Food Grade',   NULL, 175.00,'DELIVERED', 'Ian Reid',    'Weight not captured'),
('DOC-1043','2024-02-21','2024-02-22','WH03','CUST003','Steel',       37.500,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1044','2024-02-23','2024-02-24','WH04','CUST002','Chemicals',    9.000,210.00,'DELIVERED', 'Anna Moss',   NULL),
('DOC-1045','2024-02-23','2024-02-24','WH01','CUST001','Aggregates',  32.000, 82.00,'DELIVERED', 'Dave Okafor', NULL),
('DOC-1046','2024-02-26','2024-02-27','WH02','CUST004','Timber',      20.500, 95.50,'DELIVERED', 'Sue Hartley', NULL),
('DOC-1047','2024-02-26','2024-02-27','WH03','CUST008','Steel',       24.000,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1048','2024-02-28','2024-02-29','WH05','CUST005','Food Grade',  16.500,175.00,'DELIVERED', 'Ian Reid',    NULL),
-- March 2024
('DOC-1049','2024-03-01','2024-03-02','WH01','CUST001','Aggregates',  29.000, 82.00,'DELIVERED', 'Dave Okafor', NULL),
('DOC-1050','2024-03-01','2024-03-02','WH03','CUST003','Steel',       40.000,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1051','2024-03-04','2024-03-05','WH02','CUST006','Timber',      18.750, 95.50,'DELIVERED', 'Sue Hartley', NULL),
('DOC-1052','2024-03-04','2024-03-05','WH04','CUST002','Chemicals',    8.500,210.00,'DELIVERED', 'Anna Moss',   NULL),
('DOC-1053','2024-03-06','2024-03-07','WH05','CUST005','Food Grade',  21.000,175.00,'DELIVERED', 'Ian Reid',    NULL),
('DOC-1054','2024-03-06', NULL,       'WH03','CUST008','Steel',       33.000,142.00,'CANCELLED', NULL,          'Cancelled by customer'),
('DOC-1055','2024-03-08','2024-03-09','WH01','CUST004','Aggregates',  -2.500, 82.00,'DELIVERED', 'Dave Okafor', 'NEGATIVE — data entry error'),
('DOC-1056','2024-03-08','2024-03-09','WH02','CUST001','Timber',      22.000, 95.50,'DELIVERED', 'Sue Hartley', NULL),
('DOC-1057','2024-03-11','2024-03-12','WH03','CUST003','Steel',       36.500,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1058','2024-03-11','2024-03-12','WH04','CUST007','Chemicals',    7.500,210.00,'DELIVERED', 'Anna Moss',   NULL),
('DOC-1059','2024-03-13','2024-03-14','WH05','CUST005','Food Grade',  19.500,175.00,'DELIVERED', 'Ian Reid',    NULL),
('DOC-1060','2024-03-13','2024-03-14','WH01','CUST002','Aggregates',  25.000, 82.00,'DELIVERED', 'Dave Okafor', NULL),
-- DUPLICATE: DOC-1057
('DOC-1057','2024-03-11','2024-03-12','WH03','CUST003','Steel',       36.500,142.00,'DELIVERED', 'Paul Singh',  'DUPLICATE — system glitch'),
('DOC-1061','2024-03-15','2024-03-16','WH02','CUST004','Timber',      30.000, 95.50,'DELIVERED', 'Sue Hartley', NULL),
('DOC-1062','2024-03-15','2024-03-16','WH03','CUST008','Steel',       27.500,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1063','2024-03-18','2024-03-19','WH04','CUST003','Chemicals',   12.000,210.00,'DELIVERED', 'Anna Moss',   NULL),
('DOC-1064','2024-03-18','2024-03-19','WH01','CUST001','Aggregates',  21.500, 82.00,'DELIVERED', 'Dave Okafor', NULL),
('DOC-1065','2024-03-20','2024-03-21','WH05','CUST005','Food Grade',  17.000,175.00,'DELIVERED', 'Ian Reid',    NULL),
('DOC-1066','2024-03-20','2024-03-21','WH02','CUST006','Timber',      24.500, 95.50,'DELIVERED', 'Sue Hartley', NULL),
('DOC-1067','2024-03-22','2024-03-23','WH03','CUST003','Steel',       43.000,142.00,'DELIVERED', 'Paul Singh',  NULL),
('DOC-1068','2024-03-22','2024-03-23','WH01','CUST004','Aggregates',  15.000, 82.00,'DELIVERED', 'Dave Okafor', NULL),
('DOC-1069','2024-03-25','2024-03-26','WH04','CUST002','Chemicals',    9.500,210.00,'DELIVERED', 'Anna Moss',   NULL),
('DOC-1070','2024-03-25','2024-03-26','WH05','CUST005','Food Grade',  23.000,175.00,'DELIVERED', 'Ian Reid',    NULL);

-- Verification
SELECT 'Total rows'               AS check_name, COUNT(*)::TEXT AS result FROM erp.delivery_orders
UNION ALL SELECT 'Unique doc_entry',              COUNT(DISTINCT doc_entry)::TEXT FROM erp.delivery_orders
UNION ALL SELECT 'Duplicate doc_entries',         COUNT(*)::TEXT FROM (SELECT doc_entry FROM erp.delivery_orders GROUP BY doc_entry HAVING COUNT(*) > 1) d
UNION ALL SELECT 'Cancelled orders',              COUNT(*)::TEXT FROM erp.delivery_orders WHERE status = 'CANCELLED'
UNION ALL SELECT 'Negative tonnage',              COUNT(*)::TEXT FROM erp.delivery_orders WHERE quantity_tonnes < 0
UNION ALL SELECT 'NULL tonnage',                  COUNT(*)::TEXT FROM erp.delivery_orders WHERE quantity_tonnes IS NULL
UNION ALL SELECT 'Inconsistent status casing',    COUNT(*)::TEXT FROM erp.delivery_orders WHERE status != UPPER(status);
