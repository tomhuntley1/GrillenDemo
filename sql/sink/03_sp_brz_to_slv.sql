-- =============================================================================
-- usp_brz_to_slv — Bronze → Silver transformation
-- This is the "DBA as data engineer" moment of the demo.
-- Pure T-SQL: CTE, ROW_NUMBER(), CASE, UPPER(). No Spark. No new tooling.
--
-- What it does:
--   1. Deduplicates by doc_entry — keeps first occurrence (lowest order_id)
--   2. Excludes CANCELLED orders (preserved in Bronze for audit)
--   3. Standardises status to UPPER()
--   4. Floors NULL tonnage → 0, sets dq_tonnage_was_null flag
--   5. Floors negative tonnage → 0, sets dq_tonnage_was_negative flag
--   6. Calculates revenue_gbp = quantity × unit_price
--   7. Writes summary to pipeline_log
-- =============================================================================

IF OBJECT_ID('dbo.usp_brz_to_slv','P') IS NOT NULL DROP PROCEDURE dbo.usp_brz_to_slv;
GO

CREATE PROCEDURE dbo.usp_brz_to_slv
    @pipeline_run_id NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @rows_in        INT = 0;
    DECLARE @rows_out       INT = 0;
    DECLARE @dupes_removed  INT = 0;
    DECLARE @cancelled      INT = 0;
    DECLARE @nulls_floored  INT = 0;
    DECLARE @negs_floored   INT = 0;
    DECLARE @error_msg      NVARCHAR(MAX);

    BEGIN TRY

        SELECT @rows_in = COUNT(*) FROM brz.delivery_orders;

        -- Step 1: Deduplicate — keep first occurrence per doc_entry
        ;WITH ranked AS (
            SELECT *,
                ROW_NUMBER() OVER (PARTITION BY doc_entry ORDER BY order_id ASC) AS rn,
                COUNT(*)     OVER (PARTITION BY doc_entry)                        AS occurrence_count
            FROM brz.delivery_orders
        )
        SELECT order_id, doc_entry, order_date, delivery_date, warehouse_id, customer_id,
               product_category, quantity_tonnes, unit_price_gbp, status, driver_name, notes,
               CASE WHEN occurrence_count > 1 THEN 1 ELSE 0 END AS dq_was_duplicate
        INTO #deduped
        FROM ranked
        WHERE rn = 1;

        SELECT @dupes_removed = @rows_in - COUNT(*) FROM #deduped;

        -- Step 2: Remove CANCELLED
        SELECT @cancelled = COUNT(*) FROM #deduped WHERE UPPER(status) = 'CANCELLED';
        DELETE FROM #deduped WHERE UPPER(status) = 'CANCELLED';

        -- Step 3: Count DQ issues before fixing
        SELECT @nulls_floored = COUNT(*) FROM #deduped WHERE quantity_tonnes IS NULL;
        SELECT @negs_floored  = COUNT(*) FROM #deduped WHERE quantity_tonnes < 0;

        -- Step 4: Build Silver
        TRUNCATE TABLE slv.delivery_orders;

        INSERT INTO slv.delivery_orders (
            doc_entry, order_date, delivery_date, warehouse_id, customer_id,
            product_category, quantity_tonnes, unit_price_gbp, status, driver_name,
            revenue_gbp, dq_was_duplicate, dq_tonnage_was_null,
            dq_tonnage_was_negative, dq_status_was_mixed_case
        )
        SELECT
            doc_entry, order_date, delivery_date, warehouse_id, customer_id, product_category,
            -- Floor NULL and negative tonnage to 0
            CASE WHEN quantity_tonnes IS NULL THEN 0.000
                 WHEN quantity_tonnes < 0     THEN 0.000
                 ELSE quantity_tonnes END,
            unit_price_gbp,
            UPPER(status),
            driver_name,
            -- Revenue
            CASE WHEN quantity_tonnes IS NULL OR quantity_tonnes <= 0 THEN 0.00
                 WHEN unit_price_gbp IS NULL THEN 0.00
                 ELSE ROUND(CASE WHEN quantity_tonnes < 0 THEN 0 ELSE quantity_tonnes END * unit_price_gbp, 2)
            END,
            dq_was_duplicate,
            CASE WHEN quantity_tonnes IS NULL THEN 1 ELSE 0 END,
            CASE WHEN quantity_tonnes < 0     THEN 1 ELSE 0 END,
            CASE WHEN status != UPPER(status) THEN 1 ELSE 0 END
        FROM #deduped;

        SELECT @rows_out = COUNT(*) FROM slv.delivery_orders;

        -- Step 5: Reference tables
        TRUNCATE TABLE slv.warehouses;
        INSERT INTO slv.warehouses (warehouse_id, warehouse_name, city, region, capacity_tonnes)
        SELECT warehouse_id, warehouse_name, city, region, capacity_tonnes FROM brz.warehouses;

        TRUNCATE TABLE slv.customers;
        INSERT INTO slv.customers (customer_id, company_name, contact_name, city, account_status)
        SELECT customer_id, company_name, contact_name, city, account_status FROM brz.customers;

        DROP TABLE #deduped;

        -- Log
        INSERT INTO dbo.pipeline_log (pipeline_name, run_id, stage, status, rows_processed, message, completed_at)
        VALUES ('pl_northroute_elt', @pipeline_run_id, 'SILVER', 'SUCCESS', @rows_out,
            CONCAT('Bronze rows in: ', @rows_in, ' | Dupes removed: ', @dupes_removed,
                   ' | Cancelled removed: ', @cancelled, ' | NULL tonnage floored: ', @nulls_floored,
                   ' | Negative tonnage floored: ', @negs_floored, ' | Silver rows out: ', @rows_out),
            SYSUTCDATETIME());

        PRINT '=== Bronze → Silver Complete ===';
        PRINT 'Bronze in:   ' + CAST(@rows_in       AS NVARCHAR);
        PRINT 'Dupes removed: ' + CAST(@dupes_removed AS NVARCHAR);
        PRINT 'Cancelled:   ' + CAST(@cancelled     AS NVARCHAR);
        PRINT 'NULL floored: ' + CAST(@nulls_floored AS NVARCHAR);
        PRINT 'Neg floored:  ' + CAST(@negs_floored  AS NVARCHAR);
        PRINT 'Silver out:  ' + CAST(@rows_out      AS NVARCHAR);

    END TRY
    BEGIN CATCH
        SET @error_msg = ERROR_MESSAGE();
        INSERT INTO dbo.pipeline_log (pipeline_name, run_id, stage, status, message, completed_at)
        VALUES ('pl_northroute_elt', @pipeline_run_id, 'SILVER', 'FAILED', @error_msg, SYSUTCDATETIME());
        THROW;
    END CATCH;
END;
GO

PRINT 'usp_brz_to_slv created successfully.';
GO
