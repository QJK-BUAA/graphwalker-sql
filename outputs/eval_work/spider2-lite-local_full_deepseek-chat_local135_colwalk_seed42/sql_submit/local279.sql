-- We need to simulate monthly inventory for 2019. Since we don't have explicit monthly data,
-- we'll use inventory as starting point (December 2018) and product_minimums for restock rules.
-- For each product, we compute monthly ending inventory assuming:
-- - Starting inventory = current inventory qty (as of Dec 2018)
-- - Each month, if ending inventory < qty_minimum, restock by adding qty_purchase
-- - We need to find the month in 2019 where |ending_inventory - qty_minimum| is smallest
-- Since we lack monthly sales/usage data, we'll assume inventory stays constant (no consumption)
-- and only restocking events change it. The absolute difference will be same each month unless restocked.
-- To make this meaningful, we'll compute for each month the inventory after potential restock.

WITH RECURSIVE monthly_inventory AS (
    -- Base: December 2018 inventory levels
    SELECT 
        i.product_id,
        i.qty AS starting_inventory,
        pm.qty_minimum,
        pm.qty_purchase,
        0 AS month_offset, -- December 2018 is month 0
        i.qty AS ending_inventory
    FROM inventory i
    JOIN product_minimums pm ON i.product_id = pm.product_id
    
    UNION ALL
    
    -- Recursive step: for each subsequent month in 2019
    SELECT 
        mi.product_id,
        mi.ending_inventory AS starting_inventory,
        mi.qty_minimum,
        mi.qty_purchase,
        mi.month_offset + 1,
        CASE 
            WHEN mi.ending_inventory < mi.qty_minimum 
            THEN mi.ending_inventory + mi.qty_purchase 
            ELSE mi.ending_inventory 
        END AS ending_inventory
    FROM monthly_inventory mi
    WHERE mi.month_offset < 11 -- 12 months for 2019 (Jan-Dec)
)
SELECT 
    product_id,
    CASE month_offset 
        WHEN 0 THEN 'January'
        WHEN 1 THEN 'February'
        WHEN 2 THEN 'March'
        WHEN 3 THEN 'April'
        WHEN 4 THEN 'May'
        WHEN 5 THEN 'June'
        WHEN 6 THEN 'July'
        WHEN 7 THEN 'August'
        WHEN 8 THEN 'September'
        WHEN 9 THEN 'October'
        WHEN 10 THEN 'November'
        WHEN 11 THEN 'December'
    END AS month,
    ROUND(ABS(ending_inventory - qty_minimum), 4) AS abs_difference
FROM monthly_inventory
WHERE month_offset BETWEEN 0 AND 11 -- Only 2019 months (Jan=0, Dec=11)
  AND product_id IN (SELECT DISTINCT product_id FROM inventory)
ORDER BY product_id, abs_difference ASC