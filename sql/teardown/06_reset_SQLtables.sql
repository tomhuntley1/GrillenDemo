

-- Clear all data, keep structure and stored procs
DELETE FROM gld.fact_delivery;
DELETE FROM gld.dim_customer;
DELETE FROM gld.dim_warehouse;
DELETE FROM gld.dim_date;
TRUNCATE TABLE slv.delivery_orders;
TRUNCATE TABLE slv.customers;
TRUNCATE TABLE slv.warehouses;
TRUNCATE TABLE brz.delivery_orders;
TRUNCATE TABLE brz.customers;
TRUNCATE TABLE brz.warehouses;
TRUNCATE TABLE dbo.pipeline_log;

-- Reseed identity columns
DBCC CHECKIDENT ('gld.fact_delivery',  RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('gld.dim_customer',   RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('gld.dim_warehouse',  RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('dbo.pipeline_log',   RESEED, 0) WITH NO_INFOMSGS;