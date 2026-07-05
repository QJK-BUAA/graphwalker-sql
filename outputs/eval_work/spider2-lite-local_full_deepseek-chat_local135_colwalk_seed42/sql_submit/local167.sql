SELECT lt.state, COUNT(DISTINCT lt.id_bioguide) AS cnt
FROM legislators_terms lt
JOIN legislators l ON lt.id_bioguide = l.id_bioguide
WHERE l.gender = 'female'
  AND (
    (lt.term_start <= '12-31' AND lt.term_end >= '12-31')
    OR (lt.term_start LIKE '%-12-31')
    OR (lt.term_end LIKE '%-12-31')
  )
  AND lt.term_number = 1
GROUP BY lt.state
ORDER BY cnt DESC
LIMIT 1