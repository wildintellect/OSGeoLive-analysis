# R code to plot preliminary results for OSGeoLive 2011
# install.packages(c("RSQLite","car","spdep","rgdal","reshape","RColorBrewer")
library(RSQLite)
m <- dbDriver("SQLite")
con <- dbConnect(m, dbname = "osgeolivedata.sqlite",loadable.extensions = TRUE)


makeplots <- function(){
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
}


makemaps <- function(){
    ### Plotting maps
    #loading spatialite views as sp objects
    require(rgdal)
    require(RSQLite)
    require(reshape)
    require(RColorBrewer)
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

    #### Way slow with ggplot2 but does work
    #test <- readOGR("osgeolivedata.sqlite","mapContribTime",verbose=TRUE,disambiguateFIDs=TRUE)
    #library(ggplot2)
    #ggplot(test,aes())+geom_polygon()+facet_wrap(~rev)
}


fixITUdata <- function(){
    ## Reshape ITU data to long format and save back to sqlite
    # Assumes db is already connected
    library(reshape2)
    inp1 <- dbReadTable(con,"'ITU-Internet'")
    outp1 <- melt(inp1,id=c("PK_UID","Country","iso_a2"))
    dbWriteTable(con,"ITU-InternetByYear",outp1)

    inp2 <- dbReadTable(con,"'ITU-Subscriptions'")
    outp2 <- melt(inp1,id=c("PK_UID","Country"))
    dbWriteTable(con,"ITU-SubscriptionsByYear",outp2)
}


exploreplots <- function {
    codes <- unique(dspeed$country_code)
    plot(range(as.POSIXct(dspeed$date)),range(dspeed$download_kbps))
    colors <- rainbow(length(codes))

    for (i in 1:length(codes)) {   
        country <- subset(dspeed, country_code==codes[i])  
        lines(as.POSIXct(country$date), country$download_kbps, type="l", lwd=1.5,col=colors[i])
    } 

    #dspeed[,d:=as.Date(date)]
    dspeed$d<-as.Date(dspeed$date)
    #dspeed[,cc:=factor(country_code)]
    dspeed$cc<-factor(dspeed$country_code)
    ggplot(dspeed,aes(d,download_kbps,color=cc))+geom_line()
}


#Regression test download data against country metrics
downloadregression <- function(){
    require(car)
    downdata <-dbReadTable(con,"Metrics2012wAkamai")
    #Scatterplot is diagnostic
    scatterplotMatrix(downdata[-(1:4)])
    #do I need to do more sophisticated analysis considering interaction between variables?
    lmresult <-lm(downbypop ~ economy+income+average+akamaibroadband,downdata)
    capture.output(lmresult,of="download-regression.txt")    
    par(mfrow=c(2,2))
    plot(lmresult)
    #todo: save useful plot

}


exploreprojections <- function {
    require(maps)
    require(mapproj)
    require(rgdal)
    require(RSQLite)
    require(reshape)
    require(RColorBrewer)
    ne <- readOGR("osgeolivedata.sqlite","mapcountriesT",disambiguateFIDs=TRUE)

}
