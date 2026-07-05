WITH customer_profits AS (
    SELECT 
        c.cust_id,
        SUM(s.quantity_sold * (cost.unit_price - cost.unit_cost)) AS total_profit
    FROM customers c
    JOIN countries co ON c.country_id = co.country_id
    JOIN sales s ON c.cust_id = s.cust_id
    JOIN products p ON s.prod_id = p.prod_id
    JOIN costs cost ON p.prod_id = cost.prod_id AND s.time_id = cost.time_id
    JOIN times t ON s.time_id = t.time_id
    WHERE co.country_name = 'Italy'
      AND t.calendar_month_name = 'December'
      AND t.calendar_year = 2021
    GROUP BY c.cust_id
),
profit_range AS (
    SELECT 
        MIN(total_profit) AS min_profit,
        MAX(total_profit) AS max_profit,
        (MAX(total_profit) - MIN(total_profit)) / 10.0 AS bucket_width
    FROM customer_profits
),
bucketed AS (
    SELECT 
        cp.cust_id,
        cp.total_profit,
        CASE 
            WHEN cp.total_profit = pr.max_profit THEN 9
            ELSE FLOOR((cp.total_profit - pr.min_profit) / pr.bucket_width)
        END AS bucket_index
    FROM customer_profits cp
    CROSS JOIN profit_range pr
)
SELECT 
    b.bucket_index + 1 AS bucket,
    COUNT(DISTINCT b.cust_id) AS customer_count,
    MIN(b.total_profit) AS min_total_profit,
    MAX(b.total_profit) AS max_total_profit
FROM bucketed b
GROUP BY b.bucket_index
ORDER BY b.bucket_index