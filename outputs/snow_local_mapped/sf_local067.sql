WITH customer_profits AS (
    SELECT 
        c.cust_id,
        SUM(s.amount_sold - cst.unit_cost * s.quantity_sold) AS total_profit
    FROM customers c
    JOIN sales s ON c.cust_id = s.cust_id
    JOIN products p ON s.prod_id = p.prod_id
    JOIN costs cst ON p.prod_id = cst.prod_id AND s.time_id = cst.time_id
    JOIN times t ON s.time_id = t.time_id
    WHERE c.country_id = (SELECT country_id FROM customers WHERE cust_city LIKE '%Italy%' LIMIT 1)
      AND t.calendar_year = 2021
      AND t.calendar_month_number = 12
    GROUP BY c.cust_id
),
tiered_customers AS (
    SELECT 
        total_profit,
        NTILE(10) OVER (ORDER BY total_profit) AS profit_tier
    FROM customer_profits
)
SELECT 
    MAX(total_profit) AS highest_profit,
    MIN(total_profit) AS lowest_profit
FROM tiered_customers
WHERE profit_tier = 1 OR profit_tier = 10