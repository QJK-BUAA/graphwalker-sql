WITH monthly_totals AS (
  SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    strftime('%Y-%m', p.payment_date) AS month,
    SUM(p.amount) AS total_amount
  FROM customer c
  JOIN payment p ON c.customer_id = p.customer_id
  GROUP BY c.customer_id, c.first_name, c.last_name, strftime('%Y-%m', p.payment_date)
),
monthly_changes AS (
  SELECT 
    customer_id,
    first_name,
    last_name,
    month,
    total_amount,
    LAG(total_amount) OVER (PARTITION BY customer_id ORDER BY month) AS prev_total
  FROM monthly_totals
),
changes AS (
  SELECT 
    customer_id,
    first_name,
    last_name,
    ABS(total_amount - COALESCE(prev_total, 0)) AS change_amount
  FROM monthly_changes
  WHERE prev_total IS NOT NULL
)
SELECT 
  first_name || ' ' || last_name AS full_name
FROM changes
GROUP BY customer_id, first_name, last_name
ORDER BY AVG(change_amount) DESC
LIMIT 1