SELECT 
    m.L1_model,
    COUNT(*) AS total_count
FROM model m
WHERE m.L1_model IN ('regression', 'tree')
GROUP BY m.L1_model
ORDER BY total_count DESC
LIMIT 1