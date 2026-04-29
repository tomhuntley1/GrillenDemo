-- =============================================================================
-- ACT 2: BRONZE — THE TRUTH AS IT ARRIVED
-- "ADF copied it across. Every row. No judgment."
-- =============================================================================
 
-- 2a. Bronze row count vs source
--     SAY: "How many rows did we copy?"
--     STEP 1 — run this in pgAdmin to show the source count:
--        SELECT COUNT(*) FROM erp.delivery_orders;   --> 73
--
--     STEP 2 — run this in SSMS to show Bronze:
SELECT COUNT(*) AS bronze_row_count FROM brz.delivery_orders;
--     SAY: "73 in Postgres. 73 in Bronze. Exact match.
--           Bronze is a perfect replica of what the source sent us."
--     SAY: "73 and 73. Exact match. Bronze is a perfect replica."
 
 
-- 2b. The duplicate is still here
--     SAY: "DOC-1003 — is it still duplicated in Bronze?"
SELECT
    order_id,
    doc_entry,
    order_date,
    quantity_tonnes,
    status,
    notes,
    _loaded_at
FROM brz.delivery_orders
WHERE doc_entry = 'DOC-1003'
ORDER BY order_id;
--     SAY: "Yes. Both rows. Exactly as they arrived.
--           Bronze doesn't fix anything. That's not its job.
--           Its job is to be the record of what we received."
 
 
-- 2c. The negative tonnage is still here
--     SAY: "The negative tonnage?"
SELECT
    doc_entry,
    order_date,
    quantity_tonnes,
    notes,
    _loaded_at
FROM brz.delivery_orders
WHERE quantity_tonnes < 0;
--     SAY: "Still there. -4 tonnes. We received it, we kept it.
--           Now watch what Silver does with it."
 