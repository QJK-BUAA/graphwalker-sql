SELECT 
    CASE 
        WHEN t.Milliseconds < 240000 THEN 'short'
        WHEN t.Milliseconds >= 240000 AND t.Milliseconds < 600000 THEN 'medium'
        ELSE 'long'
    END AS category,
    MIN(CAST(t.Milliseconds AS REAL) / 60000.0) AS min_minutes,
    MAX(CAST(t.Milliseconds AS REAL) / 60000.0) AS max_minutes,
    SUM(il.UnitPrice * il.Quantity) AS total_revenue
FROM Track t
JOIN InvoiceLine il ON t.TrackId = il.TrackId
GROUP BY category
ORDER BY category