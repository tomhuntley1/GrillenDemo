
-- =============================================================================
-- ACT 1: THE SOURCE SYSTEM
-- "Let me show you what we're working with."
-- =============================================================================
 
-- 1a. First impression — looks reasonable
--     SAY: "73 rows. Three months of deliveries. Looks fine, right?"
SELECT
    order_id,
    doc_entry,
    order_date,
    warehouse_id,
    customer_id,
    product_category,
    quantity_tonnes,
    status
FROM erp.delivery_orders   -- run this in pgAdmin
ORDER BY order_id;
 
 
-- 1b. Look closer — the status problem
--     SAY: "How many distinct statuses do we have? Should be maybe three or four."
SELECT
    status,
    COUNT(*) AS occurrences
FROM erp.delivery_orders
GROUP BY status
ORDER BY occurrences DESC;
--     POINT AT: 'DELIVERED', 'Delivered', 'delivered' — same thing, three spellings
--     SAY: "Nobody decided to do this. It just happened."
 
 
-- 1c. The duplicate problem
--     SAY: "Now let's look for records that appear more than once."
SELECT
    doc_entry,
    COUNT(*) AS times_submitted
FROM erp.delivery_orders
GROUP BY doc_entry
HAVING COUNT(*) > 1
ORDER BY doc_entry;
--     SAY: "Three document numbers submitted twice. System glitch. Classic."
 
 
-- 1d. Show a specific duplicate side by side
--     SAY: "Here's DOC-1003. Spot the difference."
SELECT
    order_id,
    doc_entry,
    order_date,
    warehouse_id,
    quantity_tonnes,
    status,
    notes
FROM erp.delivery_orders
WHERE doc_entry = 'DOC-1003'
ORDER BY order_id;
--     POINT AT: identical rows except order_id and notes
--     SAY: "Same document. Same date. Same tonnage. Second one shouldn't exist."
 
 
-- 1e. The tonnage problems
--     SAY: "And then there's the weigh bridge data."
SELECT
    doc_entry,
    order_date,
    warehouse_id,
    quantity_tonnes,
    notes
FROM erp.delivery_orders
WHERE quantity_tonnes IS NULL
   OR quantity_tonnes < 0
ORDER BY order_date;
--     SAY: "Two NULLs — weigh bridge didn't record it.
--           Two negatives — weigh bridge recorded a return journey as a delivery.
--           We can't just delete these. They happened. We need to deal with them."
 
 
-- 1f. The full DQ scorecard
--     SAY: "So here's the score before we've done anything."
SELECT
    'Total rows'               AS check_name, COUNT(*)         AS result FROM erp.delivery_orders
UNION ALL
SELECT 'Unique doc_entry',                    COUNT(DISTINCT doc_entry)  FROM erp.delivery_orders
UNION ALL
SELECT 'Duplicate doc_entries',               COUNT(*) FROM (
    SELECT doc_entry FROM erp.delivery_orders GROUP BY doc_entry HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'Cancelled orders',                    COUNT(*) FROM erp.delivery_orders WHERE status = 'CANCELLED'
UNION ALL
SELECT 'Negative tonnage',                    COUNT(*) FROM erp.delivery_orders WHERE quantity_tonnes < 0
UNION ALL
SELECT 'NULL tonnage',                        COUNT(*) FROM erp.delivery_orders WHERE quantity_tonnes IS NULL
UNION ALL
SELECT 'Inconsistent status casing',          COUNT(*) FROM erp.delivery_orders WHERE status != UPPER(status);
--     SAY: "That's what the pipeline has to deal with.
--           Now let's see what it actually did."
 