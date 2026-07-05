WITH customer_first_payment AS (
    SELECT 
        customer_id,
        MIN(payment_date) AS first_payment_date
    FROM payment
    GROUP BY customer_id
),
customer_lifetime_sales AS (
    SELECT 
        p.customer_id,
        SUM(p.amount) AS total_lifetime_sales
    FROM payment p
    GROUP BY p.customer_id
    HAVING SUM(p.amount) > 0
),
customer_7day_sales AS (
    SELECT 
        p.customer_id,
        SUM(p.amount) AS sales_7days
    FROM payment p
    INNER JOIN customer_first_payment cfp ON p.customer_id = cfp.customer_id
    WHERE p.payment_date >= cfp.first_payment_date 
      AND p.payment_date < datetime(cfp.first_payment_date, '+7 days')
    GROUP BY p.customer_id
),
customer_30day_sales AS (
    SELECT 
        p.customer_id,
        SUM(p.amount) AS sales_30days
    FROM payment p
    INNER JOIN customer_first_payment cfp ON p.customer_id = cfp.customer_id
    WHERE p.payment_date >= cfp.first_payment_date 
      AND p.payment_date < datetime(cfp.first_payment_date, '+30 days')
    GROUP BY p.customer_id
)
SELECT 
    AVG(CAST(c7.sales_7days AS REAL) / cls.total_lifetime_sales) * 100 AS avg_pct_7days,
    AVG(CAST(c30.sales_30days AS REAL) / cls.total_lifetime_sales) * 100 AS avg_pct_30days,
    AVG(cls.total_lifetime_sales) AS avg_total_lifetime_sales
FROM customer_lifetime_sales cls
LEFT JOIN customer_7day_sales c7 ON cls.customer_id = c7.customer_id
LEFT JOIN customer_30day_sales c30 ON cls.customer_id = c30.customer_id