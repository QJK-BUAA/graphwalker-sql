-- Winning matches: player's team scored more goals than opponent
-- Losing matches: player's team scored fewer goals than opponent
-- Player participated if they appear in any of the 11 home or 11 away player slots and that slot is not NULL
-- For each player, count wins and losses separately, then find max

WITH player_matches AS (
    -- Home players in matches where home team won
    SELECT 
        p.player_api_id,
        p.player_name,
        'win' AS result
    FROM Match m
    JOIN Player p ON 
        p.player_api_id IN (
            m.home_player_1, m.home_player_2, m.home_player_3, m.home_player_4, m.home_player_5,
            m.home_player_6, m.home_player_7, m.home_player_8, m.home_player_9, m.home_player_10, m.home_player_11
        )
    WHERE m.home_team_goal > m.away_team_goal
      AND p.player_api_id IS NOT NULL
    
    UNION ALL
    
    -- Away players in matches where away team won
    SELECT 
        p.player_api_id,
        p.player_name,
        'win' AS result
    FROM Match m
    JOIN Player p ON 
        p.player_api_id IN (
            m.away_player_1, m.away_player_2, m.away_player_3, m.away_player_4, m.away_player_5,
            m.away_player_6, m.away_player_7, m.away_player_8, m.away_player_9, m.away_player_10, m.away_player_11
        )
    WHERE m.away_team_goal > m.home_team_goal
      AND p.player_api_id IS NOT NULL
    
    UNION ALL
    
    -- Home players in matches where home team lost
    SELECT 
        p.player_api_id,
        p.player_name,
        'loss' AS result
    FROM Match m
    JOIN Player p ON 
        p.player_api_id IN (
            m.home_player_1, m.home_player_2, m.home_player_3, m.home_player_4, m.home_player_5,
            m.home_player_6, m.home_player_7, m.home_player_8, m.home_player_9, m.home_player_10, m.home_player_11
        )
    WHERE m.home_team_goal < m.away_team_goal
      AND p.player_api_id IS NOT NULL
    
    UNION ALL
    
    -- Away players in matches where away team lost
    SELECT 
        p.player_api_id,
        p.player_name,
        'loss' AS result
    FROM Match m
    JOIN Player p ON 
        p.player_api_id IN (
            m.away_player_1, m.away_player_2, m.away_player_3, m.away_player_4, m.away_player_5,
            m.away_player_6, m.away_player_7, m.away_player_8, m.away_player_9, m.away_player_10, m.away_player_11
        )
    WHERE m.away_team_goal < m.home_team_goal
      AND p.player_api_id IS NOT NULL
),
player_counts AS (
    SELECT 
        player_api_id,
        player_name,
        SUM(CASE WHEN result = 'win' THEN 1 ELSE 0 END) AS wins,
        SUM(CASE WHEN result = 'loss' THEN 1 ELSE 0 END) AS losses
    FROM player_matches
    GROUP BY player_api_id, player_name
),
max_wins AS (
    SELECT MAX(wins) AS max_wins FROM player_counts
),
max_losses AS (
    SELECT MAX(losses) AS max_losses FROM player_counts
)
SELECT 
    pc.player_name AS player_with_most_wins,
    pc.wins AS win_count,
    pc2.player_name AS player_with_most_losses,
    pc2.losses AS loss_count
FROM player_counts pc
CROSS JOIN player_counts pc2
CROSS JOIN max_wins mw
CROSS JOIN max_losses ml
WHERE pc.wins = mw.max_wins
  AND pc2.losses = ml.max_losses
LIMIT 1