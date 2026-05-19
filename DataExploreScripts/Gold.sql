
-- =============================================================================
-- ACT 4: GOLD — THE TRUTH, READY TO CONSUME
-- Star schema. Dimensions. Facts. Power BI sits here.
-- =============================================================================
 
-- 4a. Trace DOC-1003 all the way to Gold
--     Let's follow DOC-1003 one more time — all the way to Gold.
SELECT
    dd.full_date,
    dd.month_name,
    dd.day_of_week,
    dw.warehouse_name,
    dw.city          AS depot_city,
    dw.region,
    dc.company_name  AS customer,
    f.product_category,
    f.quantity_tonnes,
    f.revenue_gbp,
    f.dq_was_duplicate
FROM gld.fact_delivery f
INNER JOIN gld.dim_date      dd ON f.order_date_key = dd.date_key
INNER JOIN gld.dim_warehouse dw ON f.warehouse_key  = dw.warehouse_key
INNER JOIN gld.dim_customer  dc ON f.customer_key   = dc.customer_key
WHERE f.doc_entry = 'DOC-1003';
--     In the fact table. With the flag still on it.
--     Full date context. Warehouse name. Customer name. All joined.
--     One row. Clean. Queryable.
 
 
-- 4b. Monthly revenue — the director's view
--     "Now — the kind of query a director would actually want.
SELECT
    dd.month_name,
    dd.month_num,
    COUNT(*)               AS deliveries,
    SUM(f.quantity_tonnes) AS total_tonnes,
    SUM(f.revenue_gbp)     AS total_revenue_gbp
FROM gld.fact_delivery f
INNER JOIN gld.dim_date dd ON f.order_date_key = dd.date_key
GROUP BY dd.month_name, dd.month_num
ORDER BY dd.month_num;
--     Monthly revenue. Three lines. January, February, March.
--     Automated. Repeatable. Trusted. Not a pivot table."
 
 
-- 4c. Revenue by depot with % of total
--     Which depot is driving the most revenue?
SELECT
    dw.warehouse_name,
    dw.region,
    COUNT(*)               AS deliveries,
    SUM(f.quantity_tonnes) AS total_tonnes,
    SUM(f.revenue_gbp)     AS total_revenue_gbp,
    CAST(
        SUM(f.revenue_gbp) * 100.0
        / SUM(SUM(f.revenue_gbp)) OVER ()
        AS DECIMAL(5,1)
    )                      AS pct_of_total
FROM gld.fact_delivery f
INNER JOIN gld.dim_warehouse dw ON f.warehouse_key = dw.warehouse_key
GROUP BY dw.warehouse_name, dw.region
ORDER BY total_revenue_gbp DESC;
--     Birmingham Hub, ~39%, window function column
--     Birmingham Hub. 39% of all revenue. That's a window function —
--     SUM() OVER(). One extra line of SQL.
--     That insight was buried in 73 messy rows twenty minutes ago."
 
 
-- 4d. Top customers
--     And who are northroute most dependent on as a business?
SELECT
    dc.company_name,
    dc.city,
    COUNT(*)               AS deliveries,
    SUM(f.quantity_tonnes) AS total_tonnes,
    SUM(f.revenue_gbp)     AS total_revenue_gbp
FROM gld.fact_delivery f
INNER JOIN gld.dim_customer dc ON f.customer_key = dc.customer_key
GROUP BY dc.company_name, dc.city
ORDER BY total_revenue_gbp DESC;
--     Clearwater Retail at the top. If they churn, they will feel it.
 
 
-- 4e. Product mix by month — the kind of thing you'd build a chart from
--     One more — product mix over time. The kind of thing you'd
--     drag straight into a Power BI chart
SELECT
    dd.month_name,
    dd.month_num,
    f.product_category,
    COUNT(*)               AS deliveries,
    SUM(f.quantity_tonnes) AS total_tonnes,
    SUM(f.revenue_gbp)     AS total_revenue_gbp
FROM gld.fact_delivery f
INNER JOIN gld.dim_date dd ON f.order_date_key = dd.date_key
GROUP BY dd.month_name, dd.month_num, f.product_category
ORDER BY dd.month_num, total_revenue_gbp DESC;