SELECT 
    CAST(SUM(CASE WHEN health = 'Good' THEN 1 ELSE 0 END) AS REAL) / COUNT(*) * 100 AS percentage
FROM trees
WHERE boroname = 'Bronx'