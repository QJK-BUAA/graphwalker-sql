SELECT 
  CASE 
    WHEN CAST(strftime('%Y', 'now') AS INTEGER) - CAST(substr(birth_date, 1, 4) AS INTEGER) BETWEEN 20 AND 29 THEN '20s'
    WHEN CAST(strftime('%Y', 'now') AS INTEGER) - CAST(substr(birth_date, 1, 4) AS INTEGER) BETWEEN 30 AND 39 THEN '30s'
    WHEN CAST(strftime('%Y', 'now') AS INTEGER) - CAST(substr(birth_date, 1, 4) AS INTEGER) BETWEEN 40 AND 49 THEN '40s'
    WHEN CAST(strftime('%Y', 'now') AS INTEGER) - CAST(substr(birth_date, 1, 4) AS INTEGER) BETWEEN 50 AND 59 THEN '50s'
    ELSE 'others'
  END AS age_category,
  COUNT(*) AS user_count
FROM mst_users
GROUP BY age_category