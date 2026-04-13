-- =============================================================================
-- NorthRoute Logistics — Azure SQL Setup
-- Run this first against your Azure SQL DB.
-- Creates brz, slv, gld schemas + all tables + pipeline_log.
-- =============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'brz') EXEC('CREATE SCHEMA brz'); GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'slv') EXEC('CREATE SCHEMA slv'); GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gld') EXEC('CREATE SCHEMA gld'); GO

-- =============================================================================
-- BRONZE — exact replica of source, no transformation whatsoever
-- =============================================================================
IF OBJECT_ID('brz.warehouses','U')      IS NOT NULL DROP TABLE brz.warehouses;
IF OBJECT_ID('brz.customers','U')       IS NOT NULL DROP TABLE brz.customers;
IF OBJECT_ID('brz.delivery_orders','U') IS NOT NULL DROP TABLE brz.delivery_orders;

CREATE TABLE brz.warehouses (
    warehouse_id    NVARCHAR(10), warehouse_name NVARCHAR(100), city NVARCHAR(50),
    region          NVARCHAR(50), capacity_tonnes DECIMAL(10,2),
    _loaded_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE brz.customers (
    customer_id     NVARCHAR(10), company_name NVARCHAR(100), contact_name NVARCHAR(100),
    city            NVARCHAR(50), account_status NVARCHAR(20),
    _loaded_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE brz.delivery_orders (
    order_id        INT, doc_entry NVARCHAR(20), order_date DATE, delivery_date DATE,
    warehouse_id    NVARCHAR(10), customer_id NVARCHAR(10), product_category NVARCHAR(50),
    quantity_tonnes DECIMAL(10,3), unit_price_gbp DECIMAL(10,2), status NVARCHAR(30),
    driver_name     NVARCHAR(100), notes NVARCHAR(MAX), created_at DATETIME2,
    _loaded_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- =============================================================================
-- SILVER — business rules applied, deduped, DQ flagged
-- =============================================================================
IF OBJECT_ID('slv.warehouses','U')      IS NOT NULL DROP TABLE slv.warehouses;
IF OBJECT_ID('slv.customers','U')       IS NOT NULL DROP TABLE slv.customers;
IF OBJECT_ID('slv.delivery_orders','U') IS NOT NULL DROP TABLE slv.delivery_orders;

CREATE TABLE slv.warehouses (
    warehouse_id    NVARCHAR(10) NOT NULL, warehouse_name NVARCHAR(100) NOT NULL,
    city            NVARCHAR(50) NOT NULL, region NVARCHAR(50) NOT NULL,
    capacity_tonnes DECIMAL(10,2) NOT NULL, _loaded_at DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_slv_warehouses PRIMARY KEY (warehouse_id)
);

CREATE TABLE slv.customers (
    customer_id     NVARCHAR(10) NOT NULL, company_name NVARCHAR(100) NOT NULL,
    contact_name    NVARCHAR(100), city NVARCHAR(50) NOT NULL, account_status NVARCHAR(20) NOT NULL,
    _loaded_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_slv_customers PRIMARY KEY (customer_id)
);

CREATE TABLE slv.delivery_orders (
    doc_entry               NVARCHAR(20)  NOT NULL,
    order_date              DATE          NOT NULL,
    delivery_date           DATE,
    warehouse_id            NVARCHAR(10)  NOT NULL,
    customer_id             NVARCHAR(10)  NOT NULL,
    product_category        NVARCHAR(50)  NOT NULL,
    quantity_tonnes         DECIMAL(10,3) NOT NULL,  -- NULLs and negatives floored to 0
    unit_price_gbp          DECIMAL(10,2),
    status                  NVARCHAR(30)  NOT NULL,  -- standardised to UPPER
    driver_name             NVARCHAR(100),
    revenue_gbp             DECIMAL(12,2),
    dq_was_duplicate        BIT NOT NULL DEFAULT 0,
    dq_tonnage_was_null     BIT NOT NULL DEFAULT 0,
    dq_tonnage_was_negative BIT NOT NULL DEFAULT 0,
    dq_status_was_mixed_case BIT NOT NULL DEFAULT 0,
    _loaded_at              DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_slv_delivery_orders PRIMARY KEY (doc_entry)
);

-- =============================================================================
-- GOLD — star schema, ready to query
-- =============================================================================
IF OBJECT_ID('gld.fact_delivery','U')  IS NOT NULL DROP TABLE gld.fact_delivery;
IF OBJECT_ID('gld.dim_customer','U')   IS NOT NULL DROP TABLE gld.dim_customer;
IF OBJECT_ID('gld.dim_warehouse','U')  IS NOT NULL DROP TABLE gld.dim_warehouse;
IF OBJECT_ID('gld.dim_date','U')       IS NOT NULL DROP TABLE gld.dim_date;

CREATE TABLE gld.dim_date (
    date_key    INT          NOT NULL, full_date DATE NOT NULL, day_of_week NVARCHAR(10) NOT NULL,
    day_num     TINYINT      NOT NULL, week_num TINYINT NOT NULL, month_num TINYINT NOT NULL,
    month_name  NVARCHAR(10) NOT NULL, quarter_num TINYINT NOT NULL, year_num SMALLINT NOT NULL,
    is_weekday  BIT          NOT NULL,
    CONSTRAINT PK_gld_dim_date PRIMARY KEY (date_key)
);

CREATE TABLE gld.dim_warehouse (
    warehouse_key   INT IDENTITY(1,1) NOT NULL, warehouse_id NVARCHAR(10) NOT NULL,
    warehouse_name  NVARCHAR(100) NOT NULL, city NVARCHAR(50) NOT NULL,
    region          NVARCHAR(50) NOT NULL, capacity_tonnes DECIMAL(10,2) NOT NULL,
    _loaded_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_gld_dim_warehouse PRIMARY KEY (warehouse_key),
    CONSTRAINT UQ_gld_dim_warehouse_id UNIQUE (warehouse_id)
);

CREATE TABLE gld.dim_customer (
    customer_key    INT IDENTITY(1,1) NOT NULL, customer_id NVARCHAR(10) NOT NULL,
    company_name    NVARCHAR(100) NOT NULL, contact_name NVARCHAR(100),
    city            NVARCHAR(50) NOT NULL, account_status NVARCHAR(20) NOT NULL,
    _loaded_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_gld_dim_customer PRIMARY KEY (customer_key),
    CONSTRAINT UQ_gld_dim_customer_id UNIQUE (customer_id)
);

CREATE TABLE gld.fact_delivery (
    delivery_key            INT IDENTITY(1,1) NOT NULL,
    order_date_key          INT NOT NULL, delivery_date_key INT,
    warehouse_key           INT NOT NULL, customer_key INT NOT NULL,
    doc_entry               NVARCHAR(20) NOT NULL, product_category NVARCHAR(50) NOT NULL,
    quantity_tonnes         DECIMAL(10,3) NOT NULL, unit_price_gbp DECIMAL(10,2),
    revenue_gbp             DECIMAL(12,2),
    dq_was_duplicate        BIT NOT NULL DEFAULT 0,
    dq_tonnage_was_null     BIT NOT NULL DEFAULT 0,
    dq_tonnage_was_negative BIT NOT NULL DEFAULT 0,
    _loaded_at              DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_gld_fact_delivery PRIMARY KEY (delivery_key),
    CONSTRAINT FK_fact_delivery_order_date  FOREIGN KEY (order_date_key)  REFERENCES gld.dim_date(date_key),
    CONSTRAINT FK_fact_delivery_warehouse   FOREIGN KEY (warehouse_key)   REFERENCES gld.dim_warehouse(warehouse_key),
    CONSTRAINT FK_fact_delivery_customer    FOREIGN KEY (customer_key)    REFERENCES gld.dim_customer(customer_key)
);

-- =============================================================================
-- PIPELINE LOG — every run writes here
-- =============================================================================
IF OBJECT_ID('dbo.pipeline_log','U') IS NOT NULL DROP TABLE dbo.pipeline_log;
CREATE TABLE dbo.pipeline_log (
    log_id          INT IDENTITY(1,1) NOT NULL,
    pipeline_name   NVARCHAR(200) NOT NULL, run_id NVARCHAR(200),
    stage           NVARCHAR(50)  NOT NULL, status NVARCHAR(20) NOT NULL,
    rows_processed  INT, message NVARCHAR(MAX),
    started_at      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(), completed_at DATETIME2,
    CONSTRAINT PK_pipeline_log PRIMARY KEY (log_id)
);
GO

PRINT 'Setup complete — brz(3), slv(3), gld(4), dbo.pipeline_log';
GO
