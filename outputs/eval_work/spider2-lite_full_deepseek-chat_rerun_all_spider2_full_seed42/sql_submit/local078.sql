SELECT time, interest_name, composition FROM (
  SELECT 
    strftime('%m-%Y', im.month_year) AS time,
    mp.interest_name,
    im.composition,
    ROW_NUMBER() OVER (ORDER BY im.composition DESC) AS rn_top,
    ROW_NUMBER() OVER (ORDER BY im.composition ASC) AS rn_bottom
  FROM interest_metrics im
  JOIN interest_map mp ON im.interest_id = mp.id
  WHERE im.composition IS NOT NULL
) t
WHERE rn_top <= 10 OR rn_bottom <= 10
ORDER BY composition DESC