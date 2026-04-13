-- =============================================================================
-- NorthRoute Demo — Azure SQL Teardown
-- Drops everything. Run this before reset-demo.ps1 rebuilds it.
-- =============================================================================

IF OBJECT_ID('gld.fact_delivery','U')  IS NOT NULL DROP TABLE gld.fact_delivery;
IF OBJECT_ID('gld.dim_customer','U')   IS NOT NULL DROP TABLE gld.dim_customer;
IF OBJECT_ID('gld.dim_warehouse','U')  IS NOT NULL DROP TABLE gld.dim_warehouse;
IF OBJECT_ID('gld.dim_date','U')       IS NOT NULL DROP TABLE gld.dim_date;
IF OBJECT_ID('slv.delivery_orders','U')IS NOT NULL DROP TABLE slv.delivery_orders;
IF OBJECT_ID('slv.customers','U')      IS NOT NULL DROP TABLE slv.customers;
IF OBJECT_ID('slv.warehouses','U')     IS NOT NULL DROP TABLE slv.warehouses;
IF OBJECT_ID('brz.delivery_orders','U')IS NOT NULL DROP TABLE brz.delivery_orders;
IF OBJECT_ID('brz.customers','U')      IS NOT NULL DROP TABLE brz.customers;
IF OBJECT_ID('brz.warehouses','U')     IS NOT NULL DROP TABLE brz.warehouses;
IF OBJECT_ID('dbo.usp_brz_to_slv','P')IS NOT NULL DROP PROCEDURE dbo.usp_brz_to_slv;
IF OBJECT_ID('dbo.usp_slv_to_gld','P')IS NOT NULL DROP PROCEDURE dbo.usp_slv_to_gld;
IF OBJECT_ID('dbo.pipeline_log','U')   IS NOT NULL DROP TABLE dbo.pipeline_log;
GO

IF EXISTS (SELECT 1 FROM sys.schemas WHERE name='gld') AND NOT EXISTS (SELECT 1 FROM sys.objects WHERE schema_id=SCHEMA_ID('gld')) DROP SCHEMA gld;
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name='slv') AND NOT EXISTS (SELECT 1 FROM sys.objects WHERE schema_id=SCHEMA_ID('slv')) DROP SCHEMA slv;
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name='brz') AND NOT EXISTS (SELECT 1 FROM sys.objects WHERE schema_id=SCHEMA_ID('brz')) DROP SCHEMA brz;
GO

PRINT 'Teardown complete. Azure SQL is clean.';
GO
