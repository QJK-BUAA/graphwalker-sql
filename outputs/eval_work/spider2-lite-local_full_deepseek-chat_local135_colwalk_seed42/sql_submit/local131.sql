SELECT 
    ms.StyleName,
    SUM(CASE WHEN mp.PreferenceSeq = 1 THEN 1 ELSE 0 END) AS First_Preference_Count,
    SUM(CASE WHEN mp.PreferenceSeq = 2 THEN 1 ELSE 0 END) AS Second_Preference_Count,
    SUM(CASE WHEN mp.PreferenceSeq = 3 THEN 1 ELSE 0 END) AS Third_Preference_Count
FROM Musical_Styles ms
JOIN Musical_Preferences mp ON ms.StyleID = mp.StyleID
GROUP BY ms.StyleName
ORDER BY ms.StyleName