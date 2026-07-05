SELECT 
    strftime('%m-%Y', im.month_year) AS "time(MM-YYYY)",
    mp.interest_name,
    im.composition
FROM interest_metrics im
JOIN interest_map mp ON im.interest_id = mp.id
WHERE im.composition IS NOT NULL
ORDER BY im.composition DESC
LIMIT 10