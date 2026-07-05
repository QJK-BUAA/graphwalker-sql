-- For each entertainer, get their top 2 style strengths (ordered by StyleStrength descending)
-- For each customer, get their top 2 style preferences (ordered by PreferenceSeq ascending)
-- Then join where the two style IDs match either in order or reversed
WITH entertainer_top2 AS (
    SELECT 
        e.EntertainerID,
        e.EntStageName,
        es.StyleID,
        es.StyleStrength,
        ROW_NUMBER() OVER (PARTITION BY e.EntertainerID ORDER BY es.StyleStrength DESC) AS rn
    FROM Entertainers e
    JOIN Entertainer_Styles es ON e.EntertainerID = es.EntertainerID
),
customer_top2 AS (
    SELECT 
        c.CustomerID,
        c.CustLastName,
        mp.StyleID,
        mp.PreferenceSeq,
        ROW_NUMBER() OVER (PARTITION BY c.CustomerID ORDER BY mp.PreferenceSeq ASC) AS rn
    FROM Customers c
    JOIN Musical_Preferences mp ON c.CustomerID = mp.CustomerID
)
SELECT DISTINCT
    e1.EntStageName,
    c1.CustLastName
FROM entertainer_top2 e1
JOIN entertainer_top2 e2 ON e1.EntertainerID = e2.EntertainerID AND e1.rn = 1 AND e2.rn = 2
JOIN customer_top2 c1 ON c1.rn = 1
JOIN customer_top2 c2 ON c2.CustomerID = c1.CustomerID AND c2.rn = 2
WHERE (e1.StyleID = c1.StyleID AND e2.StyleID = c2.StyleID)
   OR (e1.StyleID = c2.StyleID AND e2.StyleID = c1.StyleID)
ORDER BY e1.EntStageName, c1.CustLastName