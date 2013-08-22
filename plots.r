# R code to plot preliminary results for OSGeoLive 2011
library(RSQLite)
m <- dbDriver("SQLite")
con <- dbConnect(m, dbname = "osgeolivedata.sqlite",loadable.extensions = TRUE)


d1 <- dbReadTable(con,"byVersion")
d2 <- dbReadTable(con,"byType")

# Plot downloads by version for 2011
png(file="OSGeoByVersion.png", width=400, height=400, units="px")
#barplot(as.matrix(d1[,2:4]),beside=TRUE,ylim=c(0,2000),main="OSGeo Live Download Estmates 2011",sub="By Version",legend=c("4.5","5.0"), args.legend=c(title="Version"))
barplot(as.matrix(d1[,2:4]),beside=TRUE,ylim=c(0,6000),legend=c("4.5","5.0","5.5"), args.legend=c(title="Version"))
dev.off()

# Plot download by Type for 2011
d2 <- d2[order(d2$views),]
png(file="OSGeoByType.png", width=400, height=400, units="px")
barplot(as.matrix(d2[,2:4]),beside=TRUE,ylim=c(0,10000),legend=c("VM","Mini","ISO"), args.legend=c(title="Type"))
dev.off()

dbDisconnect(con)

#loading spatialite views as sp objects
library(rgdal)
test <- readOGR("osgeolivedata.sqlite","mapContribTime",verbose=TRUE,disambiguateFIDs=TRUE)
library(ggplot2)
ggplot(test,aes())+geom_polygon()+facet_wrap(~rev)
