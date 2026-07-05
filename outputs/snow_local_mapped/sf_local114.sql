-- This query generates a web sales report per region, including order count, total sales, and top sales reps (with ties).
-- Note: Since the schema only contains web_region, we assume other tables (orders, sales_reps, etc.) exist but are not shown.
-- We'll use common table names and join paths typical for such a report.

WITH region_sales AS (
    SELECT 
        wr.id AS region_id,
        wr.name AS region_name,
        COUNT(DISTINCT o.id) AS number_of_orders,
        SUM(oi.quantity * oi.unit_price) AS total_sales_amount
    FROM web_region wr
    LEFT JOIN customer c ON c.region_id = wr.id
    LEFT JOIN orders o ON o.customer_id = c.id
    LEFT JOIN order_items oi ON oi.order_id = o.id
    GROUP BY wr.id, wr.name
),
rep_sales AS (
    SELECT 
        wr.id AS region_id,
        wr.name AS region_name,
        sr.name AS rep_name,
        SUM(oi.quantity * oi.unit_price) AS rep_sales_amount
    FROM web_region wr
    JOIN customer c ON c.region_id = wr.id
    JOIN orders o ON o.customer_id = c.id
    JOIN order_items oi ON oi.order_id = o.id
    JOIN sales_rep sr ON sr.id = o.sales_rep_id
    GROUP BY wr.id, wr.name, sr.id, sr.name
),
top_reps AS (
    SELECT 
        region_id,
        region_name,
        rep_name,
        rep_sales_amount,
        RANK() OVER (PARTITION BY region_id ORDER BY rep_sales_amount DESC) AS rnk
    FROM rep_sales
)
SELECT 
    rs.region_name,
    rs.number_of_orders,
    rs.total_sales_amount,
    tr.rep_name,
    tr.rep_sales_amount
FROM region_sales rs
LEFT JOIN top_reps tr ON tr.region_id = rs.region_id AND tr.rnk = 1
ORDER BY rs.region_name