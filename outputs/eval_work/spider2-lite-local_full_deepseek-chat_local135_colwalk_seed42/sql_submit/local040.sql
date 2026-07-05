SELECT 
    t.boroname,
    COUNT(*) AS tree_count,
    AVG(CAST(i.Estimate_Mean_income AS REAL)) AS avg_mean_income
FROM trees t
LEFT JOIN income_trees i ON t.zipcode = i.zipcode
WHERE i.Estimate_Median_income > 0 
  AND i.Estimate_Mean_income > 0
  AND t.boroname IS NOT NULL 
  AND t.boroname != ''
GROUP BY t.boroname
ORDER BY tree_count DESC
LIMIT 3