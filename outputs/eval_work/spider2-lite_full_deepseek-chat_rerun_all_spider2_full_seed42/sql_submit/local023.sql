SELECT 
    p.player_name,
    ROUND(SUM(bs.runs_scored) * 1.0 / COUNT(DISTINCT bs.match_id), 4) AS avg_runs_per_match,
    ROUND(SUM(bs.runs_scored) * 1.0 / COUNT(DISTINCT bs.match_id), 4) AS batting_average
FROM player p
JOIN batsman_scored bs ON p.player_id = bs.match_id
JOIN match m ON bs.match_id = m.match_id
WHERE m.season_id = 5
GROUP BY p.player_id, p.player_name
ORDER BY avg_runs_per_match DESC
LIMIT 5