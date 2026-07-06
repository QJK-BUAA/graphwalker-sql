SELECT 
    FLOOR("publication_date" / 10000 / 5) * 5 AS period_start,
    COUNT(DISTINCT "publication_number") AS patent_count,
    AVG(ARRAY_SIZE("inventor_harmonized")) AS avg_inventors
FROM PATENTS.PATENTS.PUBLICATIONS
WHERE "country_code" = 'CA'
  AND "publication_date" >= 19600000
  AND "publication_date" < 20210000
  AND "inventor_harmonized" IS NOT NULL
  AND ARRAY_SIZE("inventor_harmonized") > 0
GROUP BY FLOOR("publication_date" / 10000 / 5) * 5
ORDER BY period_start