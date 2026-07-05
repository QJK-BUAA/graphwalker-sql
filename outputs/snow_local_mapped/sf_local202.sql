WITH state_stats AS (
    SELECT 
        state,
        COUNT(*) AS total_population,
        SUM(CASE WHEN aggressive = 0 THEN 1 ELSE 0 END) AS friendly_count,
        SUM(CASE WHEN aggressive = 1 THEN 1 ELSE 0 END) AS hostile_count,
        AVG(CAST(age AS REAL)) AS avg_age
    FROM alien_data
    GROUP BY state
),
top10_states AS (
    SELECT state, total_population, friendly_count, hostile_count, avg_age
    FROM state_stats
    ORDER BY total_population DESC
    LIMIT 10
)
SELECT COUNT(*) AS result
FROM top10_states
WHERE 
    (CAST(friendly_count AS REAL) / NULLIF(friendly_count + hostile_count, 0)) > 
    (CAST(hostile_count AS REAL) / NULLIF(friendly_count + hostile_count, 0))
    AND avg_age > 200