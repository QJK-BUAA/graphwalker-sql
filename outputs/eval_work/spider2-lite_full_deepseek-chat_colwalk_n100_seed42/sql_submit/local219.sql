WITH team_wins AS (
    -- Count wins for each team as home team
    SELECT 
        m.league_id,
        m.home_team_api_id AS team_api_id,
        COUNT(*) AS wins
    FROM Match m
    WHERE m.home_team_goal > m.away_team_goal
    GROUP BY m.league_id, m.home_team_api_id
    
    UNION ALL
    
    -- Count wins for each team as away team
    SELECT 
        m.league_id,
        m.away_team_api_id AS team_api_id,
        COUNT(*) AS wins
    FROM Match m
    WHERE m.away_team_goal > m.home_team_goal
    GROUP BY m.league_id, m.away_team_api_id
),
total_wins AS (
    -- Sum wins for each team across home and away
    SELECT 
        league_id,
        team_api_id,
        SUM(wins) AS total_wins
    FROM team_wins
    GROUP BY league_id, team_api_id
),
all_teams_in_league AS (
    -- Get all teams that have played in each league
    SELECT DISTINCT 
        m.league_id,
        t.team_api_id,
        t.team_long_name
    FROM Match m
    JOIN Team t ON t.team_api_id = m.home_team_api_id OR t.team_api_id = m.away_team_api_id
),
team_win_counts AS (
    -- Combine all teams with their win counts (0 for teams with no wins)
    SELECT 
        a.league_id,
        a.team_api_id,
        a.team_long_name,
        COALESCE(tw.total_wins, 0) AS total_wins
    FROM all_teams_in_league a
    LEFT JOIN total_wins tw ON a.league_id = tw.league_id AND a.team_api_id = tw.team_api_id
),
ranked_teams AS (
    -- Rank teams by total wins within each league
    SELECT 
        league_id,
        team_api_id,
        team_long_name,
        total_wins,
        ROW_NUMBER() OVER (PARTITION BY league_id ORDER BY total_wins ASC, team_api_id ASC) AS rn
    FROM team_win_counts
)
-- Select the team with the fewest wins in each league
SELECT 
    l.name AS league_name,
    r.team_long_name AS team_name,
    r.total_wins
FROM ranked_teams r
JOIN League l ON r.league_id = l.id
WHERE r.rn = 1
ORDER BY l.name