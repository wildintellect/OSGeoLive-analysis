##################################
#Alex Mandel 2009-2010
#University of Calfornia, Davis
#
#R Notes - To use run:
#source("survey1.r")
#don't forget to disconnect the database when done
#
#Required Libraries
# Most functions only require RSQLite

library(RSQLite)
m <- dbDriver("SQLite")
con <- dbConnect(m, dbname = "../PlacerAg.db",loadable.extensions = TRUE)

plotranks <- function(){
	#TODO add ColorBrewer
	#d1 <- dbReadTable(con,"FeatureScore")
	d1 <- dbGetQuery(con,'SELECT * FROM FeatureScore WHERE total > 0 ORDER BY Total')

	png(file="FeatureScore.png", width=800, height=600, units="px")

	par(las=2) # make label text perpendicular to axis
	par(mar=c(5,8,4,2)) # increase y-axis margin.
	barplot(d1$total, main="Feature Rankings", horiz=TRUE, names.arg=d1$feature,col=terrain.colors(5))
	dev.off()

	png()
	#d2 <- dbReadTable(con,"SearchScore")
	d2 <- dbGetQuery(con,'SELECT * FROM SearchScore WHERE total > 0 ORDER BY Total')

	png(file="SearchScore.png", width=800, height=600, units="px")	

	par(las=2) # make label text perpendicular to axis
	par(mar=c(5,8,4,2)) # increase y-axis margin.
	#barplot(d2$total, main="Search Rankings", horiz=TRUE, names.arg=d2$search)
	barplot(d2$total, main="Search Rankings", horiz=TRUE, names.arg=c("Features","Location","Seasonality","Product Group","Exact Product"), col=terrain.colors(5))
	dev.off()
}




#Don't forget to Disconnect when done
#dbDisconnect(con)
