WITH partnership_runs AS (
    SELECT 
        b.match_id,
        b.striker AS player1_id,
        b.non_striker AS player2_id,
        COUNT(*) AS partnership_total
    FROM ball_by_ball b
    GROUP BY b.match_id, b.striker, b.non_striker
),
individual_scores AS (
    SELECT 
        b.match_id,
        b.striker AS player_id,
        COUNT(*) AS individual_score
    FROM ball_by_ball b
    GROUP BY b.match_id, b.striker
),
ranked_partnerships AS (
    SELECT 
        pr.match_id,
        pr.player1_id,
        pr.player2_id,
        pr.partnership_total,
        ROW_NUMBER() OVER (PARTITION BY pr.match_id ORDER BY pr.partnership_total DESC) AS rn
    FROM partnership_runs pr
),
top_partnerships AS (
    SELECT 
        rp.match_id,
        rp.player1_id,
        rp.player2_id,
        rp.partnership_total,
        COALESCE(i1.individual_score, 0) AS score1,
        COALESCE(i2.individual_score, 0) AS score2
    FROM ranked_partnerships rp
    LEFT JOIN individual_scores i1 ON rp.match_id = i1.match_id AND rp.player1_id = i1.player_id
    LEFT JOIN individual_scores i2 ON rp.match_id = i2.match_id AND rp.player2_id = i2.player_id
    WHERE rp.rn = 1
)
SELECT 
    CASE 
        WHEN tp.score1 > tp.score2 THEN tp.player1_id
        WHEN tp.score2 > tp.score1 THEN tp.player2_id
        WHEN tp.player1_id > tp.player2_id THEN tp.player1_id
        ELSE tp.player2_id
    END AS player1_id,
    CASE 
        WHEN tp.score1 > tp.score2 THEN tp.player2_id
        WHEN tp.score2 > tp.score1 THEN tp.player1_id
        WHEN tp.player1_id > tp.player2_id THEN tp.player2_id
        ELSE tp.player1_id
    END AS player2_id,
    CASE 
        WHEN tp.score1 > tp.score2 THEN tp.score1
        WHEN tp.score2 > tp.score1 THEN tp.score2
        WHEN tp.player1_id > tp.player2_id THEN tp.score1
        ELSE tp.score2
    END AS player1_score,
    CASE 
        WHEN tp.score1 > tp.score2 THEN tp.score2
        WHEN tp.score2 > tp.score1 THEN tp.score1
        WHEN tp.player1_id > tp.player2_id THEN tp.score2
        ELSE tp.score1
    END AS player2_score,
    tp.partnership_total
FROM top_partnerships tp
ORDER BY tp.match_id