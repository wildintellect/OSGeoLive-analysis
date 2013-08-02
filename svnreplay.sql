--Useful sql for svnreplay

SELECT c.rev, COUNT(name),time FROM contributors as c, svnversion as v WHERE c.rev = v.rev GROUP BY c.rev


--Create Table to store OSGeo Live release Dates
CREATE TABLE if not Exists release 
( version TEXT, 
  rev INTEGER, --svn version of the tag
  time TEXT,
  codename TEXT,
  iso REAL,
  mini REAL,
  vm REAL,
);

--
-- Clean-up of contributors

-- Trim empty space
SELECT DISTINCT(trim(country)) FROM contributors;
SELECT country, Count(DISTINCT(name)) as people FROM contributors GROUP BY country;
--only the current rev, as names have changed slight each version
SELECT country, Count(DISTINCT(name)) as people FROM contributors  WHERE rev = (SELECT max(rev) FROM contributors) GROUP BY country;
UPDATE contributors SET country = trim(country);

-- Move names to osgeo_id, or flip email with country, or add missing 
UPDATE contributors SET country="New Zealand" ,email="<hamish_b yahoo com>" WHERE country LIKE "<hamish_b yahoo com>" ;
UPDATE contributors SET country="Australia" ,email="<Cameron.Shorter lisasoft com>" WHERE country LIKE "<Cameron.Shorter lisasoft com>" ;
UPDATE contributors SET country="Australia" ,email="<stefan.hansen lisasoft com>" WHERE country LIKE "<stefan.hansen lisasoft com>" ;
UPDATE contributors SET country="USA" ,osgeo_id="darkblue_b" WHERE country LIKE "darkblue_b" ;
UPDATE contributors SET country="Australia" ,osgeo_id="jive" WHERE country LIKE "jive" ;
-- Based on email he's clearly from the UK
UPDATE contributors SET country="UK" ,osgeo_id="guygriffiths" WHERE country LIKE "guygriffiths" ;
-- Was in the US at start of contribution
UPDATE contributors SET osgeo_id="ianturton" ,country = "USA" WHERE country Like "ianturton" ;
UPDATE contributores SET country = "USA" WHERE osgeo_id Like "ianturton" and country LIKE "?" ;
UPDATE contributors SET country = "Japan" WHERE osgeo_id LIKE "anton" ;
UPDATE contributors SET country = "Australia" WHERE name LIKE "Jackie Ng" AND country LIKE "";
UPDATE contributors SET name="Argyros Argyridis",email="arargyridis gmail com",country="Greece",osgeo_id="arargyridis" WHERE country LIKE "" AND email LIKE "%arargyridis%";
-- Stefan Stieniger was in Canada at start of contribution
UPDATE contributors SET country = "Canada" WHERE osgeo_id LIKE "mentaer"; 



-- Standardize country names to match natural earth
UPDATE contributors SET country = "United States" WHERE country LIKE "USA" ;
UPDATE contributors SET country = "United Kingdom" WHERE country LIKE "UK" ;
UPDATE contributors SET country = "Netherlands" WHERE country LIKE "The Netherlands" ;

--
-- Clean-up of translators
SELECT DISTINCT(country) FROM translators;
SELECT country, Count(DISTINCT(name)) as people FROM translators GROUP BY country;
--only the current rev, as names have changed slight each version
SELECT country, Count(DISTINCT(name)) as people FROM translators  WHERE rev = (SELECT max(rev) FROM translators) GROUP BY country;

UPDATE translators SET country = trim(country);

--Spelling
"Itally" --fix language too "Italilan"
UPDATE translators SET country="Italy",language="Italian" WHERE country = "Itally" OR language = "Italilan"; 
 
--Part of peoples names
UPDATE translators SET country=email,name = (name || country),email = osgeo_id WHERE country IN ("Sanchez","Sanz","Di Stefano","Puppin","Kastl") ;

--Last names of Japanese people
UPDATE translators SET country="Japan",name = (name || country),email = osgeo_id WHERE country IN ("Seki","Iwasaki","Kayama") ;

-- move to email
SELECT country FROM translators WHERE country LIKE "%com" or country LIKE "%.ru" ;

UPDATE translators SET email = country,country = "Russia" WHERE country LIKE "%.ru" ; 
"ardjakov rambler.ru" --russia
"novi-mail mail.ru" --russia
"polimax mail.ru" --russia
"filip83pov yandex.ru" --russia
"grozhentsov gispro.ru" --russia
"ergo list.ru" --russia
"avk_h mail.ru" --russia

SELECT * FROM translators WHERE country IN ("signmotion gmail.com","d.svidzinska gmail.com","rykovd gmail.com","kuzkok gmail.com","nikulin.e gmail.com","sim gis-lab.info","Nadiia.gorash gmail.com","pashtet51 gmail.com","lucadeluge gmail com","estela.llorente gmail com","amuriy gmail.com","voltron ua.fm") ;
SELECT country FROM translators WHERE email IN ("signmotion gmail.com","d.svidzinska gmail.com","rykovd gmail.com","kuzkok gmail.com","nikulin.e gmail.com","sim gis-lab.info","Nadiia.gorash gmail.com","pashtet51 gmail.com","lucadeluge gmail com","estela.llorente gmail com","amuriy gmail.com","voltron ua.fm") ;
UPDATE translators SET country = (SELECT b.country FROM translators as b WHERE translators.country = b.email LIMIT 1) WHERE translators.country IN ("signmotion gmail.com","d.svidzinska gmail.com","rykovd gmail.com","kuzkok gmail.com","nikulin.e gmail.com","sim gis-lab.info","Nadiia.gorash gmail.com","pashtet51 gmail.com","lucadeluge gmail com","estela.llorente gmail com","amuriy gmail.com","voltron ua.fm") ;
UPDATE translators SET country = "Russia" WHERE name="Vera" AND country="";

--Check by hand "???"
UPDATE translators SET country = "Spain" WHERE name = "Estela Llorente" ;

-- Standardize country names to match natural earth
UPDATE translators SET country = "United Kingdom" WHERE country LIKE "UK" ;
