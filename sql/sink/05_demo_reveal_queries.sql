-- =============================================================================
-- NorthRoute Demo — Live Reveal Queries
-- Run these in order during the demo. Each section has a narrative cue.
-- =============================================================================

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  BRONZE — "This is what the source sent us. Exactly."                   ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- 1a. All raw rows — show the audience the messy reality
SELECT order_id, doc_entry, order_date, warehouse_id, customer_id,
       product_category, quantity_tonnes, status, notes
FROM brz.delivery_orders
ORDER BY order_id;

-- 1b. Data quality summary — the "look at this mess" moment
SELECT 'Total rows in Bronze'       AS issue, COUNT(*)::TEXT AS count FROM brz.delivery_orders
UNION ALL SELECT 'Duplicate doc_entries',   COUNT(*)::TEXT FROM (SELECT doc_entry FROM brz.delivery_orders GROUP BY doc_entry HAVING COUNT(*) > 1) d
UNION ALL SELECT 'CANCELLED orders',        COUNT(*)::TEXT FROM brz.delivery_orders WHERE UPPER(status) = 'CANCELLED'
UNION ALL SELECT 'NULL tonnage',            COUNT(*)::TEXT FROM brz.delivery_orders WHERE quantity_tonnes IS NULL
UNION ALL SELECT 'Negative tonnage',        COUNT(*)::TEXT FROM brz.delivery_orders WHERE quantity_tonnes < 0
UNION ALL SELECT 'Inconsistent status',     COUNT(*)::TEXT FROM brz.delivery_orders WHERE status != UPPER(status);

-- 1c. Show a specific duplicate side by side
SELECT order_id, doc_entry, order_date, quantity_tonnes, status, notes
FROM brz.delivery_orders
WHERE doc_entry IN (SELECT doc_entry FROM brz.delivery_orders GROUP BY doc_entry HAVING COUNT(*) > 1)
ORDER BY doc_entry, order_id;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  SILVER — "The same data. Made trustworthy."                            ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- 2a. Silver rows — clean, flagged
SELECT doc_entry, order_date, warehouse_id, customer_id, product_category,
       quantity_tonnes, revenue_gbp, status,
       dq_was_duplicate, dq_tonnage_was_null, dq_tonnage_was_negative
FROM slv.delivery_orders
ORDER BY order_date, doc_entry;

-- 2b. Before vs after — the "aha" moment
SELECT
    (SELECT COUNT(*) FROM brz.delivery_orders)                              AS bronze_rows,
    (SELECT COUNT(*) FROM slv.delivery_orders)                              AS silver_rows,
    (SELECT COUNT(*) FROM brz.delivery_orders)
        - (SELECT COUNT(*) FROM slv.delivery_orders)                        AS rows_removed,
    (SELECT COUNT(*) FROM slv.delivery_orders WHERE dq_was_duplicate = 1)   AS flagged_duplicates,
    (SELECT COUNT(*) FROM slv.delivery_orders WHERE dq_tonnage_was_null = 1)     AS tonnage_was_null,
    (SELECT COUNT(*) FROM slv.delivery_orders WHERE dq_tonnage_was_negative = 1) AS tonnage_was_negative;

-- 2c. Show a specific DQ flag — tonnage floored to 0
SELECT doc_entry, order_date, quantity_tonnes, revenue_gbp,
       dq_tonnage_was_negative, dq_tonnage_was_null
FROM slv.delivery_orders
WHERE dq_tonnage_was_negative = 1 OR dq_tonnage_was_null = 1;

-- 2d. First useful business view — revenue by warehouse
SELECT s.warehouse_id, w.warehouse_name,
       COUNT(*)               AS delivery_count,
       SUM(s.quantity_tonnes) AS total_tonnes,
       SUM(s.revenue_gbp)     AS total_revenue_gbp
FROM slv.delivery_orders s
INNER JOIN slv.warehouses w ON s.warehouse_id = w.warehouse_id
GROUP BY s.warehouse_id, w.warehouse_name
ORDER BY total_revenue_gbp DESC;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  GOLD — "The truth. Ready to consume."                                  ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- 3a. Star schema in action — fact joined to all three dimensions
SELECT dd.full_date, dd.month_name, dw.warehouse_name, dw.city AS depot_city,
       dc.company_name AS customer, f.product_category,
       f.quantity_tonnes, f.revenue_gbp,
       f.dq_was_duplicate, f.dq_tonnage_was_null, f.dq_tonnage_was_negative
FROM gld.fact_delivery f
INNER JOIN gld.dim_date      dd ON f.order_date_key = dd.date_key
INNER JOIN gld.dim_warehouse dw ON f.warehouse_key  = dw.warehouse_key
INNER JOIN gld.dim_customer  dc ON f.customer_key   = dc.customer_key
ORDER BY dd.full_date;

-- 3b. Monthly revenue — the director's view
SELECT dd.month_name, dd.month_num,
       COUNT(*)               AS deliveries,
       SUM(f.quantity_tonnes) AS total_tonnes,
       SUM(f.revenue_gbp)     AS total_revenue_gbp
FROM gld.fact_delivery f
INNER JOIN gld.dim_date dd ON f.order_date_key = dd.date_key
GROUP BY dd.month_name, dd.month_num
ORDER BY dd.month_num;

-- 3c. Revenue by depot with % of total — window function
SELECT dw.warehouse_name, dw.region,
       COUNT(*)               AS deliveries,
       SUM(f.quantity_tonnes) AS total_tonnes,
       SUM(f.revenue_gbp)     AS total_revenue_gbp,
       CAST(SUM(f.revenue_gbp) * 100.0 / SUM(SUM(f.revenue_gbp)) OVER () AS DECIMAL(5,1)) AS pct_of_total
FROM gld.fact_delivery f
INNER JOIN gld.dim_warehouse dw ON f.warehouse_key = dw.warehouse_key
GROUP BY dw.warehouse_name, dw.region
ORDER BY total_revenue_gbp DESC;

-- 3d. Top customers
SELECT dc.company_name, dc.city,
       COUNT(*)               AS deliveries,
       SUM(f.quantity_tonnes) AS total_tonnes,
       SUM(f.revenue_gbp)     AS total_revenue_gbp
FROM gld.fact_delivery f
INNER JOIN gld.dim_customer dc ON f.customer_key = dc.customer_key
GROUP BY dc.company_name, dc.city
ORDER BY total_revenue_gbp DESC;


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║  PIPELINE LOG — "Every run is recorded. You have a full audit trail."   ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

SELECT log_id, stage, status, rows_processed, message,
       started_at, DATEDIFF(MILLISECOND, started_at, completed_at) AS duration_ms
FROM dbo.pipeline_log
ORDER BY log_id;
