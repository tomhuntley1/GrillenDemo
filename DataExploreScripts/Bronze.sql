-- =============================================================================
-- BRONZE — THE TRUTH AS IT ARRIVED

-- =============================================================================

-- Show all tables

select * from [brz].[customers]
select * from [brz].[delivery_orders]
select * from [brz].[warehouses]









 
-- 2a. Bronze row count 

SELECT COUNT(*) AS bronze_row_count FROM brz.delivery_orders;



--     73 in Postgres. 73 in Bronze. Exact match.

 
 









-- 2b. The duplicate is still here
--     "DOC-1003 — is it still duplicated in Bronze?"
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











 
-- 2c. The negative tonnage is still here

SELECT
    doc_entry,
    order_date,
    quantity_tonnes,
    notes,
    _loaded_at
FROM brz.delivery_orders
WHERE quantity_tonnes < 0;

 