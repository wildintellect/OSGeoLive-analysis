--Spatial Queries

--Join data based on country
SELECT a.country,a.downloads, b.name FROM 
    (SELECT country, sum(downloads) as downloads 
    FROM sfcountries 
    GROUP BY country) as a, 
  ne_10m_admin_0_countries as b 
  WHERE country = name;
--check the misses
SELECT country, downloads FROM (  
    SELECT a.country,a.downloads, b.name_long FROM 
    (SELECT country, sum(downloads) as downloads 
    FROM sfcountries 
    GROUP BY country) as a
    LEFT JOIN ne_10m_admin_0_countries as b 
    ON country = name_long
    )
WHERE name_long IS NULL;
--fix the easy ones
UPDATE sfcountries SET country="Vietnam" WHERE country LIKE "%Viet Nam%";
UPDATE sfcountries SET country="Russian Federation" WHERE country LIKE "%Russia%";
UPDATE sfcountries SET country="Republic of Korea" WHERE country LIKE "%Korea%";
UPDATE sfcountries SET country="Lao PDR" WHERE country LIKE "%Lao%";
UPDATE sfcountries SET country="Democratic Republic of the Congo" WHERE country LIKE "%Kinshasa%";
UPDATE sfcountries SET country="Côte d'Ivoire" WHERE country LIKE "%Ivory Coast%";

--'

-- Map Units from Natural Earth didn't pan out
-- However splitting France does help
-- Get France subunits and replace main France in new view that can be mapped and linked to other data
DROP VIEW If EXISTS mapcountries; 
CREATE VIEW mapcountries AS
SELECT sovereignt,name,name_long,iso_a2,pop_est,substr(economy,1,1)*1 as economy, substr(income_grp,1,1)*1 as income, "region_un", "subregion",GEOMETRY FROM ne_10m_admin_0_countries WHERE name NOT LIKE "France"
UNION
SELECT sovereignt,name,name_long,iso_a2,pop_est,substr(economy,1,1)*1 as economy, substr(income_grp,1,1)*1 as income,"region_un", "subregion",GEOMETRY FROM ne_10m_admin_0_map_units WHERE  sovereignt LIKE "France";

-- Join the data for a map, VIEW doesn't carry column type correctly
-- What about % of population
DROP TABLE IF EXISTS mapsfdownbycountry;
CREATE TABLE mapsfdownbycountry as
SELECT a.country,a.downloads,b.iso_a2,b.region_un,b.subregion,b.geometry 
FROM 
    (SELECT country, sum(downloads) as downloads 
    FROM sfcountries 
    GROUP BY country) as a
    JOIN mapcountries as b 
    ON country = name_long;

--
-- Now to map contributors and translators
--

-- Higher the count the longer+more people from a given country
SELECT country, count(a.name) as count 
FROM contributors as a 
LEFT JOIN ne_10m_admin_0_countries as b
ON country = b.name
GROUP BY country;   

--True count
SELECT country, count(distinct(a.name)) as count 
FROM contributors as a 
LEFT JOIN ne_10m_admin_0_countries as b
ON country = b.name
GROUP BY country;

--Join with map data
-- Join the rev dates first
SELECT country, name, a.rev, time 
FROM contributors as a,svnversion as b
WHERE a.rev = b.rev;

--Check that countries match
SELECT country, a.name,b.geometry 
FROM contributors as a 
LEFT JOIN ne_10m_admin_0_countries as b
ON country = b.name
GROUP BY country;


-- CREATE VIEW mapContribTime As
CREATE VIEW mapContribTime AS
SELECT a.rev,country,a.count,a.time,b.region_un,b.subregion,b.geometry 
FROM (SELECT country, a.rev,count(distinct(name)) as count, min(time) as time 
    FROM contributors as a,svnversion as b
    WHERE a.rev = b.rev
    GROUP BY country, a.rev
    ) as a 
LEFT JOIN ne_10m_admin_0_countries as b
ON country = b.name
ORDER BY rev, country;
--register it as spatial, case sensite now
INSERT INTO views_geometry_columns
(view_name, view_geometry, view_rowid, f_table_name, f_geometry_column)
VALUES ('mapContribTime', 'geometry', 'ROWID', 'ne_10m_admin_0_countries', 'Geometry');


--Create Table 1st then insert records ensures right column types
CREATE TABLE mapContribTimeT2(
  rev INT,
  country TEXT,
  count INT,
  time timestamp,
  Geometry NUM
);
--Insert
INSERT INTO mapContribTimeT2 
SELECT "rev", "country", "count", substr("time",1,16), "Geometry"
FROM "mapContribTime";



---- Import of NetIndex data from Ookla
--Find countries that don't match natural earth (used as the standard)
SELECT DISTINCT a.country,a.country_code
FROM country_daily_speeds as a 
WHERE a.country_code NOT IN (SELECT iso_a2 FROM mapcountries);
--result 1 Netherlands Islands

----import data from Akamai
SELECT DISTINCT a.iso_a2
FROM akamai2013 as a 
WHERE a.iso_a2 NOT IN (SELECT iso_a2 FROM mapcountries);

-- 3 mismatches
--BQ part of Netherlands,EU not a country,TK part of NZ

----Import data from ITU
--Cleanup country code
SELECT DISTINCT a.country, b.name, b.name_long, b.iso_a2
FROM "ITU-Internet" as a, mapcountries as b
WHERE a.country LIKE b.name OR replace(a.country,'&','and') LIKE b.name_long;

--Add iso code column to imports
ALTER TABLE "ITU-Internet"
ADD Column 'iso_a2';
--update matches
UPDATE "ITU-Internet" SET iso_a2 = (SELECT b.iso_a2
FROM mapcountries as b
WHERE country LIKE b.name OR replace(country,'&','and') LIKE b.name_long);
--fix nulls
UPDATE "ITU-Internet" SET iso_a2 = (SELECT b.iso_a2
FROM ITUtoNEmap as b
WHERE "ITU-Internet".country LIKE b.country)
WHERE iso_a2 IS NULL;

--Add iso code column to imports
ALTER TABLE "ITU-Subscriptions"
ADD Column 'iso_a2';

--repeat for other ITU data
--update matches
UPDATE "ITU-Subscriptions" SET iso_a2 = (SELECT b.iso_a2
FROM mapcountries as b
WHERE country LIKE b.name OR replace(country,'&','and') LIKE b.name_long);

--fix nulls
UPDATE "ITU-Subscriptions" SET iso_a2 = (SELECT b.iso_a2
FROM ITUtoNEmap as b
WHERE "ITU-Subscriptions".country LIKE b.country)
WHERE iso_a2 IS NULL;

---- Analysis, how long does it take someone to download
-- Calculate download times per country
SELECT DISTINCT "country","country_code", max(download_kbps) as kbps, 
((4.7*8000000)/((max(download_kbps)*3600)) as hours
FROM country_daily_speeds
GROUP BY "Country"

--With broadband subscriptions (broadband is > ISDN?)
SELECT DISTINCT a."country","country_code", max(download_kbps) as maxkbps,((4.7*8000000)/((max(download_kbps)*3600))) as hours, avg(download_kbps) as avgkbps,((4.7*8000000)/((avg(download_kbps)*3600))) as avghours,b."2012" as broadband
FROM country_daily_speeds as a
JOIN "ITU-Subscriptions" as b
ON b.iso_a2 = a.country_code
WHERE strftime('%Y',date) LIKE '2012' 
GROUP BY a."Country"


---- Analysis, what influence does internet speed, % of people with internet(broadband)
SELECT country, strftime('%Y',date) as year, min(download_kbps) as min, avg(download_kbps) as avg, max(download_kbps) as max
FROM country_daily_speeds
GROUP BY country, year

--Build up view that has all data for analysis
CREATE VIEW SpeedByCountry2012 AS
SELECT country, country_code, strftime('%Y',date) as year, min(download_kbps) as min, avg(download_kbps) as avg, max(download_kbps) as max
FROM country_daily_speeds
WHERE strftime('%Y',date) LIKE '2012'
GROUP BY country, year

CREATE VIEW Metrics2012noITU AS
-- missing some countries? Cameroon, perhaps no speed data?
SELECT a.country,b.iso_a2,a.downloads,b.pop,b.economy,b.income,(a.downloads/b.pop)*100 as downbypop, b.avg
FROM mapsfdownbycountry as a
--LEFT join to see missing data
JOIN
    (SELECT c.country, c.country_code as iso_a2,c.min,c.max,c.avg,pop_est as pop,economy,income 
    FROM SpeedByCountry2012 as c
    JOIN mapcountries as d
    ON c.country_code = d.iso_a2) 
as b
ON a.iso_a2 = b.iso_a2

--Complete set of data for anaylsis
--problem, no data on broadband for 2012, should take max from any previous year or drop?
CREATE VIEW Metrics2012wITU AS
SELECT a.country,a.iso_a2,a.downloads,a.pop,a.economy,a.income,a.downbypop, a.avg as OoklaAverage,b."2012" as ITUbroadband
FROM Metrics2012noITU as a
JOIN "ITU-Subscriptions" as b
ON a.iso_a2 = b.iso_a2

-- join akamai data
CREATE VIEW Metrics2012wAkamai AS
SELECT a.country,a.iso_a2,a.downloads,a.pop,a.economy,a.income,a.downbypop, a.OoklaAverage,a.itubroadband,b."uniqueip" as AkUniqueIP, b."average" as AkAverage, b."peak" as AkPeak, b."highbroadband" as AkHighBroadband, b."broadband"as AkBroadband, b."narrowband" as AkNarrowband
FROM Metrics2012wITU as a
JOIN akamai2013 as b
ON a.iso_a2 = b.iso_a2


--check polity data
SELECT ROWID, "row_names", "iso2c", "country", "democ", "autoc", "polity", "polity2", "durable"
FROM "polity"
ORDER BY ROWID 

-- join polity data, 120 matches
CREATE VIEW Metrics2012wPolity AS
SELECT a.country,a.iso_a2,a.downloads,a.pop,a.economy,a.income,a.downbypop, a.OoklaAverage,a.itubroadband,
a.AkUniqueIP,a.AkAverage, a.AkPeak, a.AkHighBroadband, a.AkBroadband, a.AkNarrowband,
b."polity2",b."durable"
FROM Metrics2012wAkamai as a
JOIN polity as b
ON a.iso_a2 = b.iso2c

--add isoa2 to democracy index
--check matches
SELECT Country, b.iso_a2
FROM DemocracyIndex2012 as a
LEFT JOIN mapcountries as b
ON b.name = a.country 

--add the iso codes
UPDATE DemocracyIndex2012 SET isoa2 = 
(SELECT mapcountries.iso_a2 FROM mapcountries WHERE  mapcountries.name = country )

--join democracyindex, 130 matches
CREATE VIEW Metrics2012wDemIndex AS
SELECT a.country,a.iso_a2,a.downloads,a.pop,a.economy,a.income,a.downbypop, a.OoklaAverage,a.itubroadband,
a.AkUniqueIP,a.AkAverage, a.AkPeak, a.AkHighBroadband, a.AkBroadband, a.AkNarrowband, 
b."2012" as DemIndex
FROM Metrics2012wAkamai as a
JOIN DemocracyIndex2012 as b
ON a.iso_a2 = b.isoa2


--UN Regions
-- In memory import Countries and Regions csv, merge
SELECT a."UNCode", a."Country", a."ISOa3",b."region",b."subregion"
FROM "UNm49country" as a
JOIN "UNm49region" as b ON
a."UNCode" = b."UNcode"
ORDER BY a."Country"
--Export results to csv and import to db, then join by ISO3 to naturalearth



/* Contingency table building */
SELECT "country", sum("win") as windows, sum("mac") as mac, sum("lin") as linux, sum("other") as other
FROM "sfosbycountry"
GROUP BY country


--Total counts per type
CREATE View TotDownByOs AS
SELECT 'downloads' as type, sum("win") as Windows, sum("mac") as Mac, sum("lin") as Linux, sum("other") as Other
FROM "sfosbycountry"

--ADD total to each entry
ALTER TABLE "sfosbycountry"
ADD Column 'total' INTEGER;
--Update the total
UPDATE "sfosbycountry" SET total = ("win"+"mac"+"lin"+"other");

-- Percentage for each entry
SELECT ROWID, "version", "type", "country",("win"*1.0/total) as winpr, ("mac"*1.0/total) as macpr, ("lin"*1.0/total) as linpr, ("other"*1.0/total) as other
FROM "sfosbycountry"
ORDER BY ROWID

-- Percentage by country and type
SELECT ROWID,"type", "country",(sum("win")*1.0/sum(total)) as winpr, (sum("mac")*1.0/sum(total)) as macpr, (sum("lin")*1.0/sum(total)) as linpr, (sum("other")*1.0/sum(total)) as other
FROM "sfosbycountry"
GROUP BY country,type
ORDER BY country

--Contingency, type by OS
SELECT type, sum("win") as Windows, sum("mac") as Mac, sum("lin") as Linux, sum("other") as Other
FROM "sfosbycountry"
GROUP BY Type

/* Infographic building and Contingency Table*/
--Query returns count of people per country per release
CREATE View ContribRegion AS
SELECT country,b.release as release,count(distinct(name))as count,subregion  
FROM (SELECT c.country,c.name, c.rev,region_un,subregion FROM contributors as c,mapContribTime as d WHERE c.country = d.country) as a,
svnversion as b 
WHERE a.rev = b.rev 
GROUP BY country, b.release 
ORDER BY a.country asc, b.release asc;

CREATE View TransRegion AS
SELECT country,b.release as release,count(distinct(name))as count,subregion  
FROM (SELECT c.country,c.name, c.rev,region_un,subregion FROM translators as c,mapcountries as d WHERE c.country = d.name) as a,svnversion as b 
WHERE a.rev = b.rev 
GROUP BY subregion, b.release 
ORDER BY b.release asc,a.country asc;
--alternate method, not quite the same results
SELECT a.release as release,subregion,count(Distinct(a.name)) as count
FROM (SELECT name, t.country, t.rev, release 
	FROM translators as t
	JOIN svnversion as v
	ON t.rev = v.rev) as a
JOIN mapcountries as m
ON a.country = m.name
GROUP BY release,subregion

