## Download the Polity IV database and add it to the sqlite

require(psData)
require(RSQLite)
polity.file <- PolityGet(url="http://www.systemicpeace.org/inscr/p4v2012.sav")
#Extract the 2012 data
polity.2012 <- subset(polity.file,polity.file$year==2012)
#Write to osgeolive sqlite database
m <- dbDriver("SQLite")
con <- dbConnect(m, dbname = "osgeolivedata.sqlite")
dbWriteTable(con,"polity",polity.2012)
dbDisconnect(con)

#Possible Variables, see pdf on polity4 for details
#Durable - how long since a 3pt change in Polity=(Democ-Autoc)
#Polity2 - NULLs indicate a gov in transition
# Afghanistan
# Bosnia And Herzegovina
# Egypt
# Tunisia
# Bahrain
