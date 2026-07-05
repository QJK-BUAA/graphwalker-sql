SELECT name ,  country FROM singer WHERE song_name LIKE '%Hey%'
SELECT CountryName FROM countries EXCEPT SELECT T1.CountryName FROM countries AS T1 JOIN CAR_MAKERS AS T2 ON T1.countryId  =  T2.Country;
SELECT Hometown FROM teacher GROUP BY Hometown HAVING COUNT(*)  >=  2
SELECT T2.id ,  T2.name FROM death AS T1 JOIN ship AS t2 ON T1.caused_by_ship_id  =  T2.id GROUP BY T2.id ORDER BY count(*) DESC LIMIT 1
