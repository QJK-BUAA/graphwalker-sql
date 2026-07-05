SELECT 
    p.player_name,
    ROUND(CAST(SUM(bs.runs_scored) AS REAL) / COUNT(DISTINCT bs.match_id), 4) AS avg_runs_per_match,
    ROUND(CAST(SUM(bs.runs_scored) AS REAL) / COUNT(DISTINCT bs.match_id), 4) AS batting_average
FROM player p
JOIN batsman_scored bs ON p.player_id = bs.striker_id
JOIN match m ON bs.match_id = m.match_id
WHERE m.season_id = 5
GROUP BY p.player_id, p.player_name
ORDER BY avg_runs_per_match DESC
LIMIT 5