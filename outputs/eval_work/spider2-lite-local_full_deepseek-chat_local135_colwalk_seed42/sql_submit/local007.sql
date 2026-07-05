SELECT ROUND(AVG(
    ROUND(ABS(CAST(strftime('%Y', final_game) AS REAL) - CAST(strftime('%Y', debut) AS REAL)), 2) +
    ROUND(ABS(CAST(strftime('%m', final_game) AS REAL) - CAST(strftime('%m', debut) AS REAL)) / 12.0, 2) +
    ROUND(ABS(CAST(strftime('%d', final_game) AS REAL) - CAST(strftime('%d', debut) AS REAL)) / 365.0, 2)
), 2) AS avg_career_span
FROM player
WHERE debut IS NOT NULL AND final_game IS NOT NULL