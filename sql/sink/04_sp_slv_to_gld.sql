-- =============================================================================
-- usp_slv_to_gld — Silver → Gold (FIXED: handles FK constraints correctly)
-- Deletes fact first before clearing dimensions, avoids TRUNCATE FK errors
-- =============================================================================

IF OBJECT_ID('dbo.usp_slv_to_gld','P') IS NOT NULL DROP PROCEDURE dbo.usp_slv_to_gld;
GO

CREATE PROCEDURE dbo.usp_slv_to_gld
    @pipeline_run_id NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @rows_out  INT = 0;
    DECLARE @error_msg NVARCHAR(MAX);

    BEGIN TRY

        -- Clear fact FIRST (it has FKs pointing to dims)
        DELETE FROM gld.fact_delivery;
        DBCC CHECKIDENT ('gld.fact_delivery', RESEED, 0) WITH NO_INFOMSGS;

        -- Now safe to clear dimensions
        TRUNCATE TABLE gld.dim_date;

        DELETE FROM gld.dim_warehouse;
        DBCC CHECKIDENT ('gld.dim_warehouse', RESEED, 0) WITH NO_INFOMSGS;

        DELETE FROM gld.dim_customer;
        DBCC CHECKIDENT ('gld.dim_customer', RESEED, 0) WITH NO_INFOMSGS;

        -- dim_date — full year calendar via recursive CTE
        ;WITH date_spine AS (
            SELECT CAST('2024-01-01' AS DATE) AS d
            UNION ALL
            SELECT DATEADD(DAY, 1, d) FROM date_spine WHERE d < '2024-12-31'
        )
        INSERT INTO gld.dim_date (date_key, full_date, day_of_week, day_num,
            week_num, month_num, month_name, quarter_num, year_num, is_weekday)
        SELECT
            CAST(FORMAT(d,'yyyyMMdd') AS INT),
            d,
            DATENAME(WEEKDAY, d),
            CASE DATEPART(WEEKDAY, d) WHEN 1 THEN 7 ELSE DATEPART(WEEKDAY, d) - 1 END,
            DATEPART(ISO_WEEK, d),
            MONTH(d),
            DATENAME(MONTH, d),
            DATEPART(QUARTER, d),
            YEAR(d),
            CASE WHEN DATEPART(WEEKDAY, d) IN (1,7) THEN 0 ELSE 1 END
        FROM date_spine
        OPTION (MAXRECURSION 400);

        -- dim_warehouse
        INSERT INTO gld.dim_warehouse (warehouse_id, warehouse_name, city, region, capacity_tonnes)
        SELECT warehouse_id, warehouse_name, city, region, capacity_tonnes
        FROM slv.warehouses ORDER BY warehouse_id;

        -- dim_customer
        INSERT INTO gld.dim_customer (customer_id, company_name, contact_name, city, account_status)
        SELECT customer_id, company_name, contact_name, city, account_status
        FROM slv.customers ORDER BY customer_id;

        -- fact_delivery
        INSERT INTO gld.fact_delivery (
            order_date_key, delivery_date_key, warehouse_key, customer_key,
            doc_entry, product_category, quantity_tonnes, unit_price_gbp, revenue_gbp,
            dq_was_duplicate, dq_tonnage_was_null, dq_tonnage_was_negative)
        SELECT
            CAST(FORMAT(d.order_date,'yyyyMMdd') AS INT),
            CASE WHEN d.delivery_date IS NULL THEN NULL
                 ELSE CAST(FORMAT(d.delivery_date,'yyyyMMdd') AS INT) END,
            w.warehouse_key,
            c.customer_key,
            d.doc_entry, d.product_category, d.quantity_tonnes,
            d.unit_price_gbp, d.revenue_gbp,
            d.dq_was_duplicate, d.dq_tonnage_was_null, d.dq_tonnage_was_negative
        FROM slv.delivery_orders d
        INNER JOIN gld.dim_warehouse w ON d.warehouse_id = w.warehouse_id
        INNER JOIN gld.dim_customer  c ON d.customer_id  = c.customer_id
        WHERE d.status = 'DELIVERED';

        SELECT @rows_out = COUNT(*) FROM gld.fact_delivery;

        INSERT INTO dbo.pipeline_log (pipeline_name, run_id, stage, status, rows_processed, message, completed_at)
        VALUES ('pl_northroute_elt', @pipeline_run_id, 'GOLD', 'SUCCESS', @rows_out,
            CONCAT('fact_delivery rows: ', @rows_out,
                   ' | dim_date: ',      (SELECT COUNT(*) FROM gld.dim_date),
                   ' | dim_warehouse: ', (SELECT COUNT(*) FROM gld.dim_warehouse),
                   ' | dim_customer: ',  (SELECT COUNT(*) FROM gld.dim_customer)),
            SYSUTCDATETIME());

        PRINT '=== Silver → Gold Complete ===';
        PRINT 'fact_delivery: ' + CAST(@rows_out AS NVARCHAR);

    END TRY
    BEGIN CATCH
        SET @error_msg = ERROR_MESSAGE();
        INSERT INTO dbo.pipeline_log (pipeline_name, run_id, stage, status, message, completed_at)
        VALUES ('pl_northroute_elt', @pipeline_run_id, 'GOLD', 'FAILED', @error_msg, SYSUTCDATETIME());
        THROW;
    END CATCH;
END;
GO

PRINT 'usp_slv_to_gld created successfully (FK-safe version).';
GO