

-- =============================================================================
-- SILVER — THE TRUTH MADE TRUSTWORTHY
-- Same data. Cleaned. Flagged. Trusted.
-- =============================================================================
 
-- 3a. Bronze vs Silver — the numbers
--     How many rows made it through to Silver?
SELECT
    'Bronze'                    AS layer,
    COUNT(*)                    AS rows,
    NULL                        AS dupes_removed,
    NULL                        AS cancellations_removed
FROM brz.delivery_orders
UNION ALL
SELECT
    'Silver',
    COUNT(*),
    NULL,
    NULL
FROM slv.delivery_orders
UNION ALL
SELECT
    'Removed (dupes + cancels)',
    (SELECT COUNT(*) FROM brz.delivery_orders) - (SELECT COUNT(*) FROM slv.delivery_orders),
    (SELECT COUNT(*) FROM slv.delivery_orders WHERE dq_was_duplicate = 1),
    (SELECT COUNT(*) FROM brz.delivery_orders WHERE UPPER(status) = 'CANCELLED');

--   73 in. 67 out. 6 removed. 3 duplicates. 3 cancellations.
--   But the story isn't just about what was removed.
 







 
-- 3b. Trace DOC-1003 through to Silver
--     Remember DOC-1003? The duplicate? Where is it now?
SELECT
    doc_entry,
    order_date,
    warehouse_id,
    quantity_tonnes,
    revenue_gbp,
    status,
    dq_was_duplicate,
    dq_tonnage_was_null,
    dq_tonnage_was_negative
FROM slv.delivery_orders
WHERE doc_entry = 'DOC-1003';
--     one row, dq_was_duplicate = 1
--     One row. The duplicate was removed. But the flag is set.
--     Six months from now, if someone asks 'did we have duplicate records
--     last January?' — the answer is right here. Yes. Three of them.
 
 
-- 3c. Trace the negative tonnage through to Silver
--    And the -4 tonnes?
SELECT
    doc_entry,
    order_date,
    quantity_tonnes,
    revenue_gbp,
    dq_tonnage_was_negative,
    dq_tonnage_was_null
FROM slv.delivery_orders
WHERE dq_tonnage_was_negative = 1
   OR dq_tonnage_was_null = 1;

--     quantity_tonnes = 0, revenue_gbp = 0, dq_tonnage_was_negative = 1
--     Floored to zero. Revenue zeroed out. We didn't guess a number.
--     We preserved the fact that something went wrong.
--     That's data quality transparency.
 
 
 
-- 3d. Status standardisation
--     And the inconsistent casing?
SELECT
    status,
    COUNT(*) AS occurrences
FROM slv.delivery_orders
GROUP BY status
ORDER BY occurrences DESC;
--     One status value. DELIVERED. All caps. Every row.
--     The stored procedure ran UPPER() on every status field.
--     Three spellings became one.
 
 
-- 3e. Revenue calculation
--     One more thing Silver added that wasn't in the source at all.
SELECT
    doc_entry,
    order_date,
    product_category,
    quantity_tonnes,
    unit_price_gbp,
    revenue_gbp
FROM slv.delivery_orders
WHERE dq_tonnage_was_negative = 0
  AND dq_tonnage_was_null = 0
ORDER BY revenue_gbp DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;
--     Revenue. quantity_tonnes multiplied by unit_price_gbp.
--     Didn't exist in the source. Calculated in the stored procedure.
--     This is your first business metric — and it came from a CASE expression
--     and a multiplication. No Python. No Spark. Just SQL.
 