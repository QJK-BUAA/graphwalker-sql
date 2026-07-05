-- Compute median total sales per country for countries with >4 customers
WITH customer_counts AS (
    SELECT c.Country, COUNT(DISTINCT c.CustomerId) AS num_customers
    FROM customers c
    GROUP BY c.Country
    HAVING num_customers > 4
),
country_sales AS (
    SELECT c.Country, SUM(ii.UnitPrice * ii.Quantity) AS total_sales
    FROM customers c
    JOIN invoices i ON c.CustomerId = i.CustomerId
    JOIN invoice_items ii ON i.InvoiceId = ii.InvoiceId
    WHERE c.Country IN (SELECT Country FROM customer_counts)
    GROUP BY c.Country
),
ranked_sales AS (
    SELECT total_sales,
           ROW_NUMBER() OVER (ORDER BY total_sales) AS row_num,
           COUNT(*) OVER () AS total_count
    FROM country_sales
)
SELECT AVG(total_sales) AS median_total_sales
FROM ranked_sales
WHERE row_num IN ((total_count + 1) / 2, (total_count + 2) / 2)