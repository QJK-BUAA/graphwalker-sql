WITH customer_spending AS (
    SELECT 
        c.customerid,
        c.companyname,
        SUM(od.unitprice * od.quantity) AS total_spent
    FROM customers c
    JOIN orders o ON c.customerid = o.customerid
    JOIN order_details od ON o.orderid = od.orderid
    WHERE strftime('%Y', o.orderdate) = '1998'
    GROUP BY c.customerid, c.companyname
),
customer_groups AS (
    SELECT 
        cs.customerid,
        cs.companyname,
        cs.total_spent,
        cgt.groupname
    FROM customer_spending cs
    JOIN customergroupthreshold cgt ON cs.total_spent >= cgt.rangebottom AND cs.total_spent < cgt.rangetop
),
total_customers AS (
    SELECT COUNT(DISTINCT customerid) AS total_count
    FROM customer_spending
)
SELECT 
    cg.groupname,
    COUNT(cg.customerid) AS customer_count,
    ROUND(CAST(COUNT(cg.customerid) AS REAL) / tc.total_count * 100, 4) AS percentage
FROM customer_groups cg
CROSS JOIN total_customers tc
GROUP BY cg.groupname, tc.total_count
ORDER BY cg.groupname