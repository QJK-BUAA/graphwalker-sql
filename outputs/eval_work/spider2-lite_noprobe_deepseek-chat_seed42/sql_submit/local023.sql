SELECT 
    p.player_name,
    ROUND(SUM(bs.runs_scored) * 1.0 / COUNT(DISTINCT m.match_id), 4) AS batting_average
FROM batsman_scored bs
JOIN match m ON bs.match_id = m.match_id
JOIN player_match pm ON m.match_id = pm.match_id
JOIN player p ON pm.player_id = p.player_id
WHERE m.season_id = 5
GROUP BY p.player_id, p.player_name
ORDER BY batting_average DESC
LIMIT 5