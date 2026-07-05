WITH style_scores AS (
    SELECT 
        mp.StyleID,
        SUM(
            CASE 
                WHEN mp.PreferenceSeq = 1 THEN 3
                WHEN mp.PreferenceSeq = 2 THEN 2
                WHEN mp.PreferenceSeq = 3 THEN 1
                ELSE 0
            END
        ) AS total_weighted_score
    FROM Musical_Preferences mp
    GROUP BY mp.StyleID
),
avg_score AS (
    SELECT AVG(CAST(total_weighted_score AS REAL)) AS avg_weighted_score
    FROM style_scores
)
SELECT 
    ss.StyleID,
    ABS(CAST(ss.total_weighted_score AS REAL) - avg_score.avg_weighted_score) AS score_difference
FROM style_scores ss
CROSS JOIN avg_score
ORDER BY ss.StyleID