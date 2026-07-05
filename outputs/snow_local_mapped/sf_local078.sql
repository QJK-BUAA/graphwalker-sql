-- Note: The schema does not have an interest name column or a separate interest table.
-- Since interest_id is the only identifier available, we'll use it as the interest category identifier.
-- For "time(MM-YYYY)", we'll use the month_year column which appears to be in that format.
-- Top 10 and bottom 10 based on highest composition values per interest_id

WITH interest_max_composition AS (
    SELECT 
        interest_id,
        MAX(composition) AS max_composition
    FROM interest_metrics
    GROUP BY interest_id
),
ranked_interests AS (
    SELECT 
        interest_id,
        max_composition,
        ROW_NUMBER() OVER (ORDER BY max_composition DESC) AS rank_desc,
        ROW_NUMBER() OVER (ORDER BY max_composition ASC) AS rank_asc
    FROM interest_max_composition
),
selected_interests AS (
    SELECT interest_id, max_composition
    FROM ranked_interests
    WHERE rank_desc <= 10 OR rank_asc <= 10
)
SELECT 
    im.month_year AS "time(MM-YYYY)",
    CAST(im.interest_id AS TEXT) AS "interest_name",
    im.composition
FROM interest_metrics im
INNER JOIN selected_interests si ON im.interest_id = si.interest_id
WHERE im.composition = si.max_composition
ORDER BY im.composition DESC