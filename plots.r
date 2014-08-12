# R code to plot preliminary results for OSGeoLive 2011
# install.packages(c("RSQLite","car","spdep","rgdal","reshape","RColorBrewer")
start <- function(){
    #usage con <- start()
    require(RSQLite)
    m <- dbDriver("SQLite")
    con <- dbConnect(m, dbname = "osgeolivedata.sqlite",loadable.extensions = TRUE)
    return(con)
}

end <- function(con){dbDisconnect(con)}

makeplots <- function(con){
    #3 Stacked plots about downloads and variant size
    d1 <- dbReadTable(con,"byVersion")
    d2 <- dbReadTable(con,"byType")

    # Plot downloads by version for 2011
    #png(file="OSGeoByVersion.png", width=400, height=400, units="px")
    pdf(file="OSGeoByVersion.pdf", width=8, height=8)
    #barplot(as.matrix(d1[,2:4]),beside=TRUE,ylim=c(0,2000),main="OSGeo Live Download Estmates 2011",sub="By Version",legend=c("4.5","5.0"), args.legend=c(title="Version"))
    barplot(as.matrix(d1[,2:4]),beside=TRUE,ylim=c(0,6000),legend=c("4.5","5.0","5.5"), args.legend=c(title="Version"))
    dev.off()

    # Plot download by Type for 2011
    d2 <- d2[order(d2$views),]
    #png(file="OSGeoByType.png", width=400, height=400, units="px")
    pdf(file="OSGeoByType.pdf", width=8, height=8)
    barplot(as.matrix(d2[,2:4]),beside=TRUE,ylim=c(0,10000),legend=c("VM","Mini","ISO"), args.legend=c(title="Type"))
    dev.off()

    dbDisconnect(con)
}




makemaps <- function(con){
    ### Plotting maps
    #loading spatialite views as sp objects
    require(rgdal)
    require(reshape)
    require(RColorBrewer)
    #DB connection is global for now
    #m <- dbDriver("SQLite")
    #con <- dbConnect(m, dbname = "osgeolivedata.sqlite")
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

downmap <- function(con){
    #Plot downloads vs Percent downloads/population
    require(lattice)
    require(rgdal)
    require(RColorBrewer)
    require(sp)
    #import base map layers
    #Create projection
    vand.proj <- "+proj=vandg +lon_0=0 +x_0=0 +y_0=0 +R_A +a=6371000 +b=6371000 +units=m +no_defs"
    # Import table then merge with Spatial
    ne <- readOGR("osgeolivedata.sqlite","map110downloads",disambiguateFIDs=TRUE)
    ne.vand <- spTransform(ne,CRS(vand.proj))


    #par(mfrow=c(2,1))    
    #apply factor over log of data into 9 groups with
    #Colorbrewer single color scale purple?    
    #colset <- brewer.pal(9,"RdPu")
    colset <- c("#FFFFFF",brewer.pal(5,"YlGn"))
     
    #plot and cut-off extra whitespace
    #q6 <- classIntervals(ne.vand$downloads,n=6,style="quantile")
    #noz <- ne.vand$downloads[ne.vand$downloads != 0]
    #b6q <- classIntervals(noz,n=5,style="quantile",intervalClosure="right")
    #b6q$brks[6] <- b6q$brks[6]+1
    #Plot 1 downloads
    brks <- c(1,20,100,500,2500,5200)
    #p1label <- levels(factor(c(0,paste(brks,"+")[1:5])))    
    p1label <- c("0","1-19","20-99","100-499","500-2499","2500+")    
    #p1 <- spplot(ne.vand,"downloads",at=brks,col.regions=colset,col=gray(.7),colorkey=list(space="bottom"),main="Downloads",key.space="bottom")
    #p1 <- spplot(ne.vand,"downloads",col.regions=colset,col=gray(.8),cuts=5,do.log=TRUE)
    p1 <- spplot(ne.vand,"downloads",at=brks,col.regions=colset,col=gray(.7),colorkey=FALSE,key=list(text=list(p1label),col.fill=colset,space="bottom",rectangle=TRUE),main="Downloads",key.space="bottom")

    #Plot 2 downloads by population
    #q6 <- classIntervals(ne.vand$downbypop,n=6,style="quantile")
    #brks2 <- c(.00047,.0009,.0019,.0038,.0075,.016)
    #brks2 <- c(.00001,.00005,.0001,.0005,.01,.016)
    brks2 <- c(0,.00001,.00005,.0001,.0005,.01,.02)    
    #p2 <- spplot(ne.vand,"downbypop",at=q6$brks,col.regions=colset,col=gray(.8))
    #p2 <- spplot(ne.vand,"downbypop",col.regions=colset,col=gray(.8),cuts=5,do.log=TRUE, main="Downloads by Percent of Population")
    #p2label <- levels(factor(c(0,paste(brks2,"+")[1:5])))
    p2label <-  c("0","0.00001+","0.00005","0.0001+","0.0005+","0.01+")
    #p2 <- spplot(ne.vand,"downbypop",at=brks2,col.regions=colset,col=gray(.7),colorkey=list(space="bottom"),main="Downloads by Percent of Population",key.space="bottom")
    colset2 <- c("#FFFFFF",brewer.pal(6,"YlGn"))

   p2 <- spplot(ne.vand,"downbypop",at=brks2,col.regions=colset,col=gray(.7),colorkey=FALSE,key=list(text=list(p2label),col=colset2,space="bottom",rectangle=TRUE),main="Downloads by Percent of Population")


    pdf("DownloadMap.pdf",width=7,height=10)
    #Actually layout plots with Trellis
    print(p1,split=c(1,1,1,2),more=TRUE)
    print(p2,split=c(1,2,1,2))
    dev.off()
}


fancyplot <- function(con){
    require(RColorBrewer)
    require(rgdal)
    #Get a List of the release dates and versions
    d1 <- dbReadTable(con,"release")
    #d2 <- dbReadTable(con,"ContribRegion")
    #Query returns count of people per country per release
    d2sql <- "SELECT release,subregion,sum(count) as count FROM ContribRegion GROUP BY release,subregion ORDER BY subregion"    
    d2 <- dbGetQuery(con,d2sql)

    #d3sql <- "SELECT release,subregion,sum(count) as Tcount FROM TransRegion GROUP BY release,subregion"    
    #d3 <- dbGetQuery(con,d3sql)
    d3sql <- "SELECT release,subregion,count FROM TransRegion ORDER BY subregion"
    #d3 <- dbReadTable(con,"TransRegion")
    d3 <- dbGetQuery(con,d3sql)
       

    #Add fake data to make the graphs match nice.
    d3 <- rbind(d3,c("2","Western Europe",0),c("3","Western Europe",0),c("4","Western Europe",0))
    d3$count <- as.integer(d3$count)
    #Contrib plot
    d2t <-xtabs(count~subregion+release,data=d2)

    #There are 10 distinct subregions currently
    subregion <- unique(c(d3$subregion,d2$subregion))
    #allcolors <- (rainbow(length(subregion)))
    #names(allcolors) <- subregion
    
    
    #2 on page
    pdf(file="RegionalParticipation.pdf",width=10,height=7)
    #par(mfrow=c(2,1))
    layout(matrix(c(1,2,1,2,3,4), 3, 2, byrow = TRUE))
    colset <- brewer.pal(10,"Paired")
    names(colset) <- sort(subregion)

    #colset <- coltable[coltable$subregion %in% unique(d2$subregion),1]
    #colset <- row.names %in% unique(d2$subregion)
    #colset <- allcolors[names(allcolors) %in% unique(d2$subregion)]
    #colset <- brewer.pal(9,"Set1")
    colset1 <- colset[names(colset) %in% unique(d2$subregion)]
    barplot(d2t,col=colset1,xlab="Contributors",horiz=TRUE,xlim=rev(range(0,90)),las=1,yaxt="n")
    #legend("topleft",legend=rownames(d2t),fill=colset1)
    
    #Trans plot - TODO merge somehow with contrin plot
    d3t <-xtabs(count~subregion+release,data=d3)

    #colset <- allcolors[names(allcolors) %in% unique(d3$subregion)]
    #colset <- coltable[coltable$subregion %in% unique(d3$subregion),1]
    #colset <- brewer.pal(9,"Set1")
    colset2 <- colset[names(colset) %in% unique(d3$subregion)]
    barplot(d3t,col=colset2,xlab="Translators",ylab="Release",horiz=TRUE,las=1)
    #legend("topleft",legend=rownames(d3t),fill=colset2)
    #dev.off()

    #get total number of releases
    cnt <- length(d1)

    #try the ggplot2 way
    #require(ggplot2)
    #require(grid)
    #require(gridExtra)
    #TODO Make the number of colors variable for more regions
    #n <- if
    #colset <- brewer.pal(10,"Paired")
    #names(colset) <- subregion
    #collegend <- scale_fill_manual(values=colset)
    #gC <- ggplot(d2, aes(release,count,fill=subregion))+geom_bar()+coord_flip() + scale_y_reverse()+theme(legend.position="none")+ggtitle("Contributors")+scale_fill_manual(values=colset)
    #gT <- ggplot(d3, aes(release,count,fill=subregion))+geom_bar()+coord_flip()+ggtitle("Translators")+scale_fill_manual(values=colset)+theme(legend.position="none")
    #gLeg <- legend("center",legend=names(colset),fill=colset)
    #TODO Broken
    #gLeg <- grid.draw(guide_legend(collegend$legend_desc()))
   

    #Alt idea, plot a map as a 3rd chart below with legend of dissolved countries by subregion    
    nesregion <- readOGR("osgeolivedata.sqlite","subregionsT",disambiguateFIDs=TRUE)    
    
    #utah = readOGR(dsn=".", layer="eco_l3_ut")
    #utah@data$id = rownames(utah@data)
    nesregion.filter <- nesregion[nesregion@data$subregion %in% names(colset),]
    nesregion.filter@data$subregion <- factor(nesregion.filter@data$subregion)

    #opar <- par()
    par(mar=c(0,0,0,0)) 
    plot(0, 0, type = "n", bty = "n", xaxt = "n", yaxt = "n",ann=FALSE)
    legend("top",legend=names(colset),fill=colset,cex=1.25)

    par(mar=c(2,0,0,2)) 
    plot(nesregion,col="white",bg="gray")
    plot(nesregion.filter,col=colset,add=TRUE)  
    dev.off()    

    #par <- opar
    #spplot(nesregion.filter,col.regions=colset)

    #nesregion.poly = fortify(nesregion.filter,region="subregion")
    #nesregion.bpoly = fortify(nesregion,region="subregion")
    #ne.poly = fortify(ne, region="subregion")
    #utah.df = join(utah.points, utah@data, by="id")
    #ne.poly <- 
    #ggplot(ne.poly,aes())+geom_polygon()
    #gmap <- ggplot(ne.polyaes(long,lat,group=group,fill=id)+geom_polygon()+geom_path(color="white")+coord_equal()+scale_fill_manual(values=colset,guide = guide_legend(title = NULL))

    #gmap <- ggplot()+geom_polygon(data=nesregion.bpoly,aes(long,lat),fill="gray80")

#geom_polygon(ne.poly,aes(long,lat,group=group,fill=id))+geom_path(color="white")+coord_equal()+scale_fill_manual(values=colset,guide = guide_legend(title = NULL))

    #theme(legend.position="bottom")
    #grid.arrange(gC,gT,gmap,ncol=2,nrow=2)


    #multiplot(gC,gT,cols=2)
    #gl <-grid.layout(1,2)    
    #grid.newpage()
    #pushViewport(viewport(layout = gl))
    #pushViewport(viewport(layout.pos.col=1,layout.pos.row=1))
    #print(gC,vp=subplot(1,1))
    #pushViewport(viewport(layout.pos.col=2,layout.pos.row=1))
    #print(gT,vp=subplot(1,2))
    #scale_fill_manual(values=region_cols)

    #Setup a stacked set of plots
    #row 1, map by version
    #row 2, downloads by region - barplot
    #row 3, line graph of contributors and translators
    #ltest <- rbind(seq(1,7),rep(8,7),rep(9,7))
    #dynamic version
    #ltest <- rbind(seq(1,cnt),rep(cnt+1,cnt),rep(cnt+2,cnt))
    #nf <- layout(ltest)
    #layout.show(nf)
}

MacVnet <- function(con){
    dsql <- 'SELECT * FROM "Metrics2012wDemIndex" WHERE ITUbroadband IS NOT NULL'
    downdata <- dbGetQuery(con,dsql)
    bycountry <- dbReadTable(con,"CountryByOSCounts")
    
}


