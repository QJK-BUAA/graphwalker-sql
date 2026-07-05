-- Note: The schema does not have an interest name column or a separate interest table.
-- Since only interest_metrics is available and it lacks interest names, we can only return
-- interest_id as a proxy for the interest category, along with month_year and composition.
-- For top 10 and bottom 10, we need to first find each interest_id's maximum composition,
-- then rank them, and finally get the top and bottom 10 records with their month details.

WITH max_composition AS (
    SELECT 
        interest_id,
        MAX(composition) AS max_comp
    FROM interest_metrics
    GROUP BY interest_id
),
ranked AS (
    SELECT 
        interest_id,
        max_comp,
        ROW_NUMBER() OVER (ORDER BY max_comp DESC) AS rn_desc,
        ROW_NUMBER() OVER (ORDER BY max_comp ASC) AS rn_asc
    FROM max_composition
),
selected_ids AS (
    SELECT interest_id FROM ranked WHERE rn_desc <= 10
    UNION
    SELECT interest_id FROM ranked WHERE rn_asc <= 10
)
SELECT 
    m.month_year AS "time(MM-YYYY)",
    CAST(m.interest_id AS TEXT) AS "interest_name",
    m.composition
FROM interest_metrics m
INNER JOIN selected_ids s ON m.interest_id = s.interest_id
WHERE m.composition = (
    SELECT MAX(m2.composition) 
    FROM interest_metrics m2 
    WHERE m2.interest_id = m.interest_id
)
ORDER BY m.composition DESC