SELECT 
    t.team_long_name,
    SUM(wins) AS total_wins
FROM (
    SELECT 
        t.team_api_id,
        COUNT(*) AS wins
    FROM Match m
    JOIN Team t ON m.home_team_api_id = t.team_api_id
    WHERE m.home_team_goal > m.away_team_goal
    GROUP BY t.team_api_id
    UNION ALL
    SELECT 
        t.team_api_id,
        COUNT(*) AS wins
    FROM Match m
    JOIN Team t ON m.away_team_api_id = t.team_api_id
    WHERE m.away_team_goal > m.home_team_goal
    GROUP BY t.team_api_id
) AS sub
JOIN Team t ON sub.team_api_id = t.team_api_id
GROUP BY t.team_long_name
ORDER BY total_wins DESC
LIMIT 10