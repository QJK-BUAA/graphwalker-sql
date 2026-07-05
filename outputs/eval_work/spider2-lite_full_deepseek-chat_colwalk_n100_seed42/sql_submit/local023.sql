SELECT 
    p.player_name,
    ROUND(AVG(CAST(bs.runs_scored AS REAL)), 4) AS batting_average
FROM player p
JOIN player_match pm ON p.player_id = pm.player_id
JOIN match m ON pm.match_id = m.match_id
JOIN batsman_scored bs ON pm.match_id = bs.match_id
WHERE m.season_id = 5
GROUP BY p.player_id, p.player_name
ORDER BY batting_average DESC
LIMIT 5