SELECT 
    ms.StyleName,
    SUM(CASE WHEN mp.PreferenceSeq = 1 THEN 1 ELSE 0 END) AS FirstPrefCount,
    SUM(CASE WHEN mp.PreferenceSeq = 2 THEN 1 ELSE 0 END) AS SecondPrefCount,
    SUM(CASE WHEN mp.PreferenceSeq = 3 THEN 1 ELSE 0 END) AS ThirdPrefCount
FROM Musical_Styles ms
JOIN Musical_Preferences mp ON ms.StyleID = mp.StyleID
WHERE mp.PreferenceSeq IN (1, 2, 3)
GROUP BY ms.StyleID, ms.StyleName