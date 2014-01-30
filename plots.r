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


### Plotting maps
#loading spatialite views as sp objects
library(rgdal)
library(RSQLite)
library(reshape)
library(RColorBrewer)
m <- dbDriver("SQLite")
con <- dbConnect(m, dbname = "osgeolivedata.sqlite")
#test <- readOGR("osgeolivedata.sqlite","mapContribTime",verbose=TRUE,disambiguateFIDs=TRUE)

#Define Robinson Projection
rob.proj <- "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"


# Import table then merge with Spatial
ne <- readOGR("osgeolivedata.sqlite","mapcountriesT",disambiguateFIDs=TRUE)
ne.rob <- spTransform(ne,CRS(rob.proj)) 

sql <- "SELECT country, a.rev,count(distinct(name)) as count FROM contributors as a,svnversion as b WHERE a.rev = b.rev GROUP BY country, a.rev ORDER BY a.rev desc,a.country asc"
data <- dbGetQuery(con,sql)
tdata <- cast(data,country~rev,value="count")
#replace NA with 0 
tdata[is.na(tdata)] <- 0

#Keep only the country name for matching
ne.rob@data <- as.data.frame(ne.rob@data["name"])

# Match up and add to attribute table
# http://www.maths.lancs.ac.uk/~rowlings/Teaching/UseR2012/crime.html#img-unnamed-chunk-8
mdata <- tdata[match(ne.rob$name,tdata$country),]
#ne.rob@data <- cbind(ne.rob@data,mdata[,-1])
ne.rob@data[is.na(ne.rob@data)] <- 0
#ne.rob@data <- as.data.frame(mdata[,-1])
ne.rob@data <- as.data.frame(mdata[,-1])

#have to set the number of possible levels so all plots match
ne.rob@data <- as.data.frame(lapply(ne.rob@data,factor,levels=c(0:17) ))
#examples
spplot(ne.rob,c("X10004","X10006"))
spplot(ne.rob,names(ne.rob@data[,c(5:10)]))
spplot(ne.rob,c("X10004","X10006"),col.regions=colset, col=gray(.8))

#by hand figure out number of factor levels
str(ne.rob@data["X10004"])
#Strech colorbrewer over that
colset <- colorRampPalette(brewer.pal(9,"RdPu"))(17)
#add white as 0
colset <-append("#FFFFFF",colset)

pdf("ContributorMap.pdf",width=36,height=24)
spplot(ne.rob,col.regions=colset,edge.col=gray(.8))
dev.off()

# Way slow with ggplot2
test <- readOGR("osgeolivedata.sqlite","mapContribTime",verbose=TRUE,disambiguateFIDs=TRUE)
library(ggplot2)
ggplot(test,aes())+geom_polygon()+facet_wrap(~rev)


## Reshape ITU data to long format and save back to sqlite
library(reshape2)
inp1 <- dbReadTable(con,"'ITU-Internet'")
outp1 <- melt(inp1,id=c("PK_UID","Country","iso_a2"))
dbWriteTable(con,"ITU-InternetByYear",outp1)

inp2 <- dbReadTable(con,"'ITU-Subscriptions'")
outp2 <- melt(inp1,id=c("PK_UID","Country"))
dbWriteTable(con,"ITU-SubscriptionsByYear",outp2)


