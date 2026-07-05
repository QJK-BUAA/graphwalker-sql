SELECT p.player_name, 
       CAST(SUM(w.over_id) AS REAL) / COUNT(*) AS bowling_avg
FROM wicket_taken w
JOIN player p ON w.player_out = p.player_id
GROUP BY p.player_id, p.player_name
ORDER BY bowling_avg ASC
LIMIT 1