SELECT 
    p.name_given,
    b.g AS games_played,
    b.r AS runs,
    b.h AS hits,
    b.hr AS home_runs
FROM batting b
JOIN player p ON b.player_id = p.player_id
ORDER BY b.g DESC, b.r DESC, b.h DESC, b.hr DESC
LIMIT 1