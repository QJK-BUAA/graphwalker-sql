WITH monthly_avg AS (
    SELECT 
        im._month,
        im._year,
        im.month_year,
        im.interest_id,
        imap.interest_name,
        AVG(CAST(im.composition AS REAL) / NULLIF(im.index_value, 0)) AS avg_composition
    FROM interest_metrics im
    JOIN interest_map imap ON im.interest_id = imap.id
    WHERE im.month_year BETWEEN '09-2018' AND '08-2019'
    GROUP BY im._month, im._year, im.month_year, im.interest_id, imap.interest_name
),
monthly_max AS (
    SELECT 
        _month,
        _year,
        month_year,
        interest_name,
        avg_composition AS max_index_composition
    FROM (
        SELECT 
            *,
            ROW_NUMBER() OVER (PARTITION BY _month, _year ORDER BY avg_composition DESC) AS rn
        FROM monthly_avg
    ) t
    WHERE rn = 1
),
rolling AS (
    SELECT 
        _month,
        _year,
        month_year,
        interest_name,
        max_index_composition,
        AVG(max_index_composition) OVER (
            ORDER BY _year, _month 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_avg_3month,
        LAG(interest_name, 1) OVER (ORDER BY _year, _month) AS prev1_interest_name,
        LAG(max_index_composition, 1) OVER (ORDER BY _year, _month) AS prev1_max_composition,
        LAG(interest_name, 2) OVER (ORDER BY _year, _month) AS prev2_interest_name,
        LAG(max_index_composition, 2) OVER (ORDER BY _year, _month) AS prev2_max_composition
    FROM monthly_max
)
SELECT 
    month_year AS date,
    interest_name,
    ROUND(max_index_composition, 4) AS max_index_composition,
    ROUND(rolling_avg_3month, 4) AS rolling_avg_3month,
    prev1_interest_name AS interest_name_1_month_ago,
    ROUND(prev1_max_composition, 4) AS max_index_composition_1_month_ago,
    prev2_interest_name AS interest_name_2_months_ago,
    ROUND(prev2_max_composition, 4) AS max_index_composition_2_months_ago
FROM rolling
ORDER BY _year, _month