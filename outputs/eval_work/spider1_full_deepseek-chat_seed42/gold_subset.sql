SELECT name ,  country FROM singer WHERE song_name LIKE '%Hey%'	concert_singer
SELECT weight FROM pets ORDER BY pet_age LIMIT 1	pets_1
SELECT CountryName FROM countries EXCEPT SELECT T1.CountryName FROM countries AS T1 JOIN CAR_MAKERS AS T2 ON T1.countryId  =  T2.Country;	car_1
SELECT count(*) FROM AIRLINES	flight_2
SELECT name FROM employee ORDER BY age	employee_hire_evaluation
SELECT document_id ,  template_id ,  Document_Description FROM Documents WHERE document_name  =  "Robbin CV"	cre_Doc_Template_Mgt
SELECT Hometown FROM teacher GROUP BY Hometown HAVING COUNT(*)  >=  2	course_teach
SELECT name FROM museum WHERE num_of_staff  >  (SELECT min(num_of_staff) FROM museum WHERE open_year  >  2010)	museum_visit
SELECT count(DISTINCT loser_name) FROM matches	wta_1
SELECT T2.id ,  T2.name FROM death AS T1 JOIN ship AS t2 ON T1.caused_by_ship_id  =  T2.id GROUP BY T2.id ORDER BY count(*) DESC LIMIT 1	battle_death
SELECT first_name ,  middle_name ,  last_name FROM Students ORDER BY date_left ASC LIMIT 1	student_transcripts_tracking
SELECT id FROM tv_channel GROUP BY country HAVING count(*)  >  2	tvshow
SELECT T1.Name FROM people AS T1 JOIN poker_player AS T2 ON T1.People_ID  =  T2.People_ID ORDER BY T2.Final_Table_Made	poker_player
SELECT T1.area_code FROM area_code_state AS T1 JOIN votes AS T2 ON T1.state  =  T2.state GROUP BY T1.area_code ORDER BY count(*) DESC LIMIT 1	voter_1
SELECT Name ,  Population ,  LifeExpectancy FROM country WHERE Continent  =  "Asia" ORDER BY SurfaceArea DESC LIMIT 1	world_1
SELECT Record_Company FROM orchestra GROUP BY Record_Company ORDER BY COUNT(*) DESC LIMIT 1	orchestra
SELECT name ,  grade FROM Highschooler	network_1
SELECT T1.treatment_type_description FROM Treatment_types AS T1 JOIN Treatments AS T2 ON T1.treatment_type_code  =  T2.treatment_type_code GROUP BY T1.treatment_type_code ORDER BY sum(cost_of_treatment) ASC LIMIT 1	dog_kennels
SELECT Citizenship ,  COUNT(*) FROM singer GROUP BY Citizenship	singer
SELECT property_name FROM Properties WHERE property_type_code  =  "House" UNION SELECT property_name FROM Properties WHERE property_type_code  =  "Apartment" AND room_count  >  1	real_estate_properties
