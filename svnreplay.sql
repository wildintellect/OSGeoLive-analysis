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

-- Sort download numbers for plotting
-- clean version numbers
SELECT ltrim(ltrim(rtrim(rtrim(rtrim(rtrim(file,".iso"),".7z"),"-min"),".1"),"osgeo-live"),"mini-") FROM osgeodowndata2011
UPDATE osgeodowndata2011 SET version =  ltrim(ltrim(rtrim(rtrim(rtrim(rtrim(file,".iso"),".7z"),"-min"),".1"),"osgeo-live"),"mini-")  WHERE version !=3 OR version IS NULL;
-- set type
UPDATE osgeodowndata2011 SET type="mini" WHERE file LIKE "%mini%";
UPDATE osgeodowndata2011 SET type="full" WHERE file NOT LIKE "%mini%" AND file LIKE "%iso";
UPDATE osgeodowndata2011 SET type="vm" WHERE file LIKE "%7z";

-- select data for plot
SELECT version,type,(sum(viewed)) as downloads FROM osgeodowndata2011 GROUP BY version, type


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
-- Klokan lives/works in switzerland
UPDATE contributors SET country = "Switzerland" WHERE osgeo_id LIKE "klokan";



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
UPDATE translators SET country = "Russia" WHERE trim(name)="Vera" AND country="";

--Check by hand "???"
UPDATE translators SET country = "Spain" WHERE name = "Estela Llorente" ;

-- Standardize country names to match natural earth
UPDATE translators SET country = "United Kingdom" WHERE trim(country) LIKE "UK" ;

-- A few more corrections
UPDATE translators SET country = "Colombia" WHERE name Like "Andrea Y%";
UPDATE translators SET country = "Spain" WHERE name Like "Diego G%";

--Add OSGeo-Live release version to svnrevision info
ALTER TABLE svnversion ADD COLUMN release TEXT;
UPDATE svnversion SET release = CASE WHEN rev BETWEEN 0 AND 2503 THEN 2
WHEN rev BETWEEN 2504 AND 4351 THEN 3
WHEN rev BETWEEN 4352 AND 4882 THEN 4
WHEN rev BETWEEN 4882 AND 6052 THEN 4.5
WHEN rev BETWEEN 6052 AND 7175 THEN 5
WHEN rev BETWEEN 7176 AND 7817 THEN 5.5
WHEN rev BETWEEN 7818 AND 9097 THEN 6.0
WHEN rev BETWEEN 9097 AND 10041 THEN 6.5
WHEN rev > 10041 THEN 7
END;


--Cleaning up name changes to avoid double counting
UPDATE Translators SET name = 'Diego González' WHERE name Like 'Diego GonzÃ¡lez';
UPDATE Translators SET name = 'Agustín Díez' WHERE name Like 'AgustÃ­n DÃ­ez' OR name LIKE 'Agustín Díez' OR name LIKE 'Agustín Dí­ez';
UPDATE Translators SET name = 'Anna Muñoz' WHERE name Like 'Anna MuÃ±oz';
UPDATE Translators SET name = 'Assumpció Termens' WHERE name Like 'Assumpcio Termens';
UPDATE Translators SET name = 'Javier Sánchez' WHERE name Like 'Javier Sanchez';
UPDATE Translators SET name = 'Jesús Gómez' WHERE name Like 'JesÃºs GÃ³mez';
UPDATE Translators SET name = 'Jorge Arévalo' WHERE name Like 'Jorge ArÃ©valo';
UPDATE Translators SET name = 'Lucía Sanjaime' WHERE name Like 'LucÃ­a Sanjaime';
UPDATE Translators SET name = 'Roberto Antolín' WHERE name Like 'Roberto AntolÃ­n';
UPDATE Translators SET name = 'Òscar Fonts' WHERE name Like 'Oscar Fonts' OR name LIKE 'Ã’scar Fonts';
UPDATE Translators SET name = 'Daniel Kastl' WHERE name Like 'DanielKastl';
UPDATE Translators SET name = 'Haruyuki Seki' WHERE name Like 'HaruyukiSeki';
UPDATE Translators SET name = 'Javier Sánchez' WHERE name Like 'JavierSanchez';
UPDATE Translators SET name = 'Jorge Sanz' WHERE name Like 'JorgeSanz';
UPDATE Translators SET name = 'José Antonio Canalejo' WHERE name Like 'JosÃ© Antonio Canalejo';
UPDATE Translators SET name = 'Massimo Di Stefano' WHERE name Like 'MassimoDi Stefano';
UPDATE Translators SET name = 'Nobusuke Iwasaki' WHERE name Like 'NobusukeIwasaki';
UPDATE Translators SET name = 'Roberto Antolín' WHERE name Like 'Roberto Antolí­n';
UPDATE Translators SET name = 'Valenty González' WHERE name Like 'Valenty Gonzalez';
UPDATE Translators SET name = 'avk_h' WHERE email Like 'avk_h mail.ru';
UPDATE Translators SET name = 'kuzkok' WHERE email Like 'kuzkok';
UPDATE Translators SET name = 'Yoichi Kayama' WHERE name Like 'YoichiKayama';
UPDATE Translators SET name = 'Marc-André Barbeau' WHERE name Like 'Marc-Andre Barbeau';


--Fix Contributors table too
UPDATE Contributors SET name = 'Jody Garnett' WHERE name Like 'Jody Garnett%';
UPDATE Contributors SET name = 'Marc-André Barbeau' WHERE name Like 'Marc-Andre Barbeau';
UPDATE Contributors SET name = 'Eike Hinderk Jürrens' WHERE name Like 'Eike Hinderk Jrrens';
UPDATE Contributors SET name = 'François Prunayre' WHERE name Like 'Fran?ois Prunayre';
UPDATE Contributors SET name = 'Johan van de Wauw' WHERE name Like 'Johan Van de Wauw';
UPDATE Contributors SET name = 'Michaël Michaud' WHERE name Like 'Micha?l Michaud';
UPDATE Contributors SET name = 'Pirmin Kalberer' WHERE name Like 'Pirmin kalberer';
UPDATE Contributors SET name = 'Sergio Baños' WHERE name Like 'Sergio Ba?os';
UPDATE Contributors SET name = 'Gérald Fenoy' WHERE name Like 'Grald Fenoy';
UPDATE Contributors SET name = 'Nathaniel V. Kelso' WHERE name Like 'Nathaniel Kelso';

-----
-- Number of Unique people
-----
SELECT distinct(c.name),t.name FROM contributors as c
LEFT JOIN translators as t ON
c.name Like t.name
ORDER BY t.name;

SELECT distinct(t.name),c.name FROM translators as t
LEFT JOIN contributors as c ON
c.name Like t.name
ORDER BY c.name;
--87 contributors,88 translators, 15 people are both
