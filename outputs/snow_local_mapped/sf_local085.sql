SELECT 
    e.employeeid,
    COUNT(CASE WHEN o.shippeddate >= o.requireddate THEN 1 END) AS late_orders,
    ROUND(100.0 * COUNT(CASE WHEN o.shippeddate >= o.requireddate THEN 1 END) / COUNT(*), 4) AS late_percentage
FROM employees e
JOIN orders o ON e.employeeid = o.employeeid
GROUP BY e.employeeid
HAVING COUNT(*) > 50
ORDER BY late_percentage DESC
LIMIT 3