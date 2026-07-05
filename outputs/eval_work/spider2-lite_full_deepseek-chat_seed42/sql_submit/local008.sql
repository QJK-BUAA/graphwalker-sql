SELECT 
    p.name_given,
    (b.g + b.r + b.h + b.hr) AS score
FROM batting b
JOIN player p ON b.player_id = p.player_id
ORDER BY score DESC
LIMIT 1