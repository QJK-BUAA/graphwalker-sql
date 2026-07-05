SELECT 
    s.businessentityid AS salesperson_id,
    strftime('%Y', s.modifieddate) AS year,
    s.salesytd - s.salesquota AS difference
FROM salesperson s
ORDER BY s.businessentityid, year