WITH monthly_balances AS (
    SELECT 
        customer_id,
        strftime('%m', txn_date) AS month,
        SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END) -
        SUM(CASE WHEN txn_type = 'withdrawal' THEN txn_amount ELSE 0 END) AS month_end_balance
    FROM customer_transactions
    WHERE txn_date LIKE '2020%'
    GROUP BY customer_id, strftime('%m', txn_date)
),
positive_counts AS (
    SELECT 
        month,
        COUNT(customer_id) AS positive_customer_count
    FROM monthly_balances
    WHERE month_end_balance > 0
    GROUP BY month
),
min_max_months AS (
    SELECT 
        month,
        positive_customer_count,
        CASE 
            WHEN positive_customer_count = (SELECT MAX(positive_customer_count) FROM positive_counts) THEN 'highest'
            WHEN positive_customer_count = (SELECT MIN(positive_customer_count) FROM positive_counts) THEN 'lowest'
        END AS category
    FROM positive_counts
    WHERE positive_customer_count = (SELECT MAX(positive_customer_count) FROM positive_counts)
       OR positive_customer_count = (SELECT MIN(positive_customer_count) FROM positive_counts)
),
avg_balances AS (
    SELECT 
        m.month,
        m.category,
        AVG(b.month_end_balance) AS avg_balance
    FROM min_max_months m
    JOIN monthly_balances b ON m.month = b.month
    GROUP BY m.month, m.category
)
SELECT 
    MAX(CASE WHEN category = 'highest' THEN avg_balance END) -
    MAX(CASE WHEN category = 'lowest' THEN avg_balance END) AS balance_difference
FROM avg_balances