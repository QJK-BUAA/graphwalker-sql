WITH team_wins AS (
    -- Count wins for each team as home team
    SELECT 
        l.name AS league_name,
        t.team_long_name AS team_name,
        COUNT(*) AS wins
    FROM League l
    JOIN Match m ON m.league_id = l.id
    JOIN Team t ON t.team_api_id = m.home_team_api_id
    WHERE m.home_team_goal > m.away_team_goal
    GROUP BY l.id, t.team_api_id
    
    UNION ALL
    
    -- Count wins for each team as away team
    SELECT 
        l.name AS league_name,
        t.team_long_name AS team_name,
        COUNT(*) AS wins
    FROM League l
    JOIN Match m ON m.league_id = l.id
    JOIN Team t ON t.team_api_id = m.away_team_api_id
    WHERE m.away_team_goal > m.home_team_goal
    GROUP BY l.id, t.team_api_id
),
total_wins AS (
    -- Sum wins from home and away for each team in each league
    SELECT 
        league_name,
        team_name,
        SUM(wins) AS total_wins
    FROM team_wins
    GROUP BY league_name, team_name
),
all_teams AS (
    -- Include all teams that have played at least one match in the league
    SELECT DISTINCT
        l.name AS league_name,
        t.team_long_name AS team_name
    FROM League l
    JOIN Match m ON m.league_id = l.id
    JOIN Team t ON t.team_api_id IN (m.home_team_api_id, m.away_team_api_id)
),
team_win_counts AS (
    -- Combine all teams with their win counts (0 if no wins)
    SELECT 
        at.league_name,
        at.team_name,
        COALESCE(tw.total_wins, 0) AS total_wins
    FROM all_teams at
    LEFT JOIN total_wins tw ON at.league_name = tw.league_name AND at.team_name = tw.team_name
),
ranked_teams AS (
    -- Rank teams by total wins within each league
    SELECT 
        league_name,
        team_name,
        total_wins,
        ROW_NUMBER() OVER (PARTITION BY league_name ORDER BY total_wins ASC, team_name ASC) AS rn
    FROM team_win_counts
)
-- Select the team with the fewest wins in each league
SELECT 
    league_name,
    team_name,
    total_wins
FROM ranked_teams
WHERE rn = 1
ORDER BY league_name