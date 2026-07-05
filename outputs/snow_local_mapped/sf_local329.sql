SELECT COUNT(DISTINCT f1.session) AS unique_sessions
FROM form_log f1
JOIN form_log f2 ON f1.session = f2.session
WHERE f1.path = '/regist/input'
  AND f2.path = '/regist/confirm'
  AND f1.stamp < f2.stamp