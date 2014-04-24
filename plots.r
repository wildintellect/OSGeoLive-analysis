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
    require(RSQLite)
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


fixITUdata <- function(con){
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


exploreplots <- function(con){
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
downloadregression <- function(con){
    require(car)
    downdata <-dbReadTable(con,"Metrics2012wAkamai")
    #Scatterplot is diagnostic
    scatterplotMatrix(downdata[-(1:4)])
    #do I need to do more sophisticated analysis considering interaction between variables?
    lmresult <-lm(downbypop ~ economy+income+akaverage+akbroadband,downdata)
    capture.output(lmresult,of="download-regression.txt")    
    par(mfrow=c(2,2))
    plot(lmresult)
    #todo: save useful plot

}


exploreprojections <- function(){
    require(maps)
    require(mapproj)
    require(rgdal)
    require(RSQLite)
    require(reshape)
    require(RColorBrewer)
    ne <- readOGR("osgeolivedata.sqlite","mapcountriesT",disambiguateFIDs=TRUE)

}

spatialauto <- function(){
    require(cshapes)
    require(psData)
    #load countries
    countrylist <- cshp(date=as.Date("2012-6-30"),useGW=TRUE)
    #make a neighborlist, warning this is CPU resource intensive
    countrynb <-distlist(date=as.Date("2012-6-30"),useGW=TRUE,type="mindist",tolerance=0.1)
    #swap in the ISO1AL2 country codes
    #match the country codes to data for correlation test

    #calculate spatial-autocorrelation


    #download polity IV database of governments, save to db
}


testRandom <- function(con){
    #Set the seed to the psuedo random number generator for repeatable results
    set.seed(9)
    require(randomForest)
    require(ROCR)
    downdata <-dbReadTable(con,"Metrics2012wDemIndex")
    #Set the seed?, is this necessary?
    #set.seed(1)
    #split the data into training and test data, 1/2
    train = sample(1:nrow(downdata),nrow(downdata)/2)

    #economy and income should probably be factors
    downdata$economy <- as.factor(downdata$economy)
    downdata$income <- as.factor(downdata$income)
    #build a random forest regression
    #mtry default is p/3 unless doing bagging
    #ntree can be change
    #Potentially use tuneRF to find the mtry and ntree values to use
    # itu-broadband had nulls values
    downdata.rf <- randomForest(downbypop ~ economy+income+ooklaaverage+akuniqueip+akaverage+akpeak+akhighbroadband+akbroadband+aknarrowband+DemIndex, data=downdata, subset=train, keep.forest=TRUE,importance = TRUE)
    importance(downdata.rf)
    
    #party might be better since its a mix of categorical(ordinal) and (interval)
    downdata.cf <- cforest(downbypop ~ economy+income+ooklaaverage+akuniqueip+akaverage+akpeak+akhighbroadband+akbroadband+aknarrowband+DemIndex, data=downdata, subset=train)
    

    #Is the formula right?
    #Maybe don't need to divided downloads by population, so that forest can tell if population matters
    #uniqueip is dangerous since number of ip's is highly controlled, and early adopters have larger share - maybe this makes it a good measure?
    
    #Population is a big driver, is it better to just multiply downbypop*100? to make it more readable
    #downdata.cf <- cforest(downloads ~ pop+economy+income+average+peak+highbroadband+akamaibroadband+narrowband+DemIndex+itubroadband, data=downdata, subset=train)
    
    #Try to figure out which variables are important, conditional means assume the variables are correlated
    downdata.varimp <- varimp(downdata.cf, conditional=TRUE)

    #Plot with a line at the abs(of the biggest negative)
    #http://www.stanford.edu/~stephsus/R-randomforest-guide.pdf
    pdf(file="ImportantVariables.pdf",width=6,height=8)
    par(oma=c(2,4,2,2))
    barplot(sort(downdata.varimp),horiz=TRUE, las=1)
    abline(v=abs(min(downdata.varimp)), col='red',lty='longdash', lwd=2)
    dev.off()

    require(corrgram)
    pdf(file="CorrelationMatrix.pdf",width=6,height=6)
    corrgram(downdata, order=TRUE, lower.panel=panel.shade,  upper.panel=panel.pie, text.panel=panel.txt,  main="OSGeo Download, PCA ordered") 
    dev.off()
       
}


OSanalysis <- function(con){
    require(Deducer)
    #file to hold output of tests
    of <- "ContingencyResults.txt"
    capture.output(print(date()),file=of,append=FALSE)

    #Two nominal variables - County and Operating System
    #http://udel.edu/~mcdonald/statgtestind.html
    downbyos <- dbReadTable(con,"TotDownByOs")
    compbyos <- c(92.02,6.81,1.16,0.00)
    downbyos.mat <- as.matrix(downbyos[1,-1]/sum(downbyos[1,-1])*100)
    downbyos.cont <- rbind(downbyos.mat,compbyos)
    row.names(downbyos.cont) <- c("downloads","computers")      
    #chisq.test(downbyos.cont)
    downbyos.lt <- likelihood.test(downbyos.cont)
    capture.output(print(downbyos.lt),file=of,append=TRUE)
    #	Pearson's Chi-squared test
    #data:  downbyos.cont
    #X-squared = 25.4531, df = 3, p-value = 1.241e-05

    #Summary information
    #Convert to percentages, calculate min, max, avg, std_dev by column


    #Contigency analysis of Type of Download by OS of Downloader 
    typebyos <- dbReadTable(con,"TypeByOS")
    typebyos.cont <- as.matrix((typebyos[,-1]))
    row.names(typebyos.cont) <- typebyos[,1]
    typebyos.lt <- likelihood.test(typebyos.cont)
    capture.output(print(typebyos.lt),file=of,append=TRUE)

    #	Log likelihood ratio (G-test) test of independence without correction
    #data:  typebyos.cont
    #Log likelihood ratio statistic (G) = 950.6209, X-squared df = 6,
    #p-value < 2.2e-16
    
    #Contingency analysis of Countries by Downloads, Contributors and Translators
    downsSQL <- 'SELECT "country", sum(total) as downloads FROM "sfosbycountry"GROUP BY country ORDER BY country;'
    downs <- dbGetQuery(con,downsSQL)
    contribSQL <- 'SELECT country,count(name) as contributors FROM contributors as a, (SELECT max(rev) as mrev FROM "contributors") as b WHERE rev = mrev GROUP BY Country;'
    contrib <- dbGetQuery(con,contribSQL)
    transSQL <- 'SELECT country,count(name) as translators FROM translators as a,(SELECT max(rev) as mrev FROM "translators") as b WHERE rev = mrev GROUP BY Country;'
    trans <- dbGetQuery(con,transSQL)
    country.df <- merge(downs,contrib,all.x=TRUE)
    country.df <- merge(country.df,trans,all.x=TRUE)
    #Replace NA with 0
    country.df[is.na(country.df)] <- 0
    #Convert to martix contingency table
    country.cont <- as.matrix(country.df[,-1])
    row.names(country.cont) <- country.df[,1]
    country.lt <- likelihood.test(country.cont)
    capture.output(print(country.lt),file=of,append=TRUE)
    #Log likelihood ratio (G-test) test of independence without correction
    #data:  country.cont
    #Log likelihood ratio statistic (G) = 367.4859, X-squared df = 320,
    #p-value = 0.03457
    #This test comes out different now, there was a bug in the code before
        
    #Maybe correlation test is unecessary?
    #cor.s = cor.test(country.cont[,1],country.cont[,2],method="kendall")
    
    

    #Contingency analysis of Countries By OS variation
    # the tails of Windows use(none/100) seem to have something in common
    countrybyos <- dbReadTable(con,"CountryByOS")
    countrybyos.cont <- as.matrix(countrybyos[,-1])
    row.names(countrybyos.cont) <- countrybyos[,1]
    countrybyos.lt <- likelihood.test(countrybyos.cont)
    capture.output(print(countrybyos.lt),file=of,append=TRUE)
    #Log likelihood ratio (G-test) test of independence without correction
    #data:  countrybyos.cont
    #Log likelihood ratio statistic (G) = 10848.92, X-squared df = 480,
    #p-value < 2.2e-16
    
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
    d3sql <- "SELECT * FROM TransRegion ORDER BY subregion"
    #d3 <- dbReadTable(con,"TransRegion")
    d3 <- dbGetQuery(con,d3sql)
    
    #Contrib plot
    d2t <-xtabs(count~subregion+release,data=d2)

    #There are 10 distinct subregions currently
    #subregion <- unique(c(d3$subregion,d2$subregion))
    #allcolors <- (rainbow(length(subregion)))
    #names(allcolors) <- subregion
    
    
    #2 on page
    pdf(file="RegionalParticipation.pdf",width=6,height=9)
    #par(mfrow=c(2,1))
    
    #colset <- coltable[coltable$subregion %in% unique(d2$subregion),1]
    #colset <- row.names %in% unique(d2$subregion)
    #colset <- allcolors[names(allcolors) %in% unique(d2$subregion)]
    #colset <- brewer.pal(9,"Set1")
    #barplot(d2t,col=colset,xlab="Release",ylab="Contributors")
    #legend("topleft",legend=rownames(d2t),fill=colset)

    #Trans plot - TODO merge somehow with contrin plot
    d3t <-xtabs(count~subregion+release,data=d3)

    #colset <- allcolors[names(allcolors) %in% unique(d3$subregion)]
    #colset <- coltable[coltable$subregion %in% unique(d3$subregion),1]
    #colset <- brewer.pal(9,"Set1")
    #barplot(d3t,col=colset,xlab="Release",ylab="Translators")
    #legend("topleft",legend=rownames(d3t),fill=colset)
    #dev.off()

    #get total number of releases
    cnt <- length(d1)

    #try the ggplot2 way
    require(ggplot2)
    require(grid)
    require(gridExtra)
    #TODO Make the number of colors variable for more regions
    #n <- if
    colset <- brewer.pal(10,"Paired")
    names(colset) <- subregion
    collegend <- scale_fill_manual(values=colset)
    gC <- ggplot(d2, aes(release,count,fill=subregion))+geom_bar()+coord_flip() + scale_y_reverse()+theme(legend.position="none")+ggtitle("Contributors")+scale_fill_manual(values=colset)
    gT <- ggplot(d3, aes(release,count,fill=subregion))+geom_bar()+coord_flip()+ggtitle("Translators")+scale_fill_manual(values=colset)+theme(legend.position="top")
    #gLeg <- legend("center",legend=names(colset),fill=colset)
    #TODO Broken
    #gLeg <- grid.draw(guide_legend(collegend$legend_desc()))
   

    #Alt idea, plot a map as a 3rd chart below with legend of dissolved countries by subregion    
    ne <- readOGR("osgeolivedata.sqlite","subregionsT",disambiguateFIDs=TRUE)    
    
    #utah = readOGR(dsn=".", layer="eco_l3_ut")
    #utah@data$id = rownames(utah@data)
    ne.poly = fortify(ne, region="subregion")
    #utah.df = join(utah.points, utah@data, by="id")
    #ne.poly <- 
    #ggplot(ne.poly,aes())+geom_polygon()
    gmap <- ggplot(ne.poly)+aes(long,lat,group=group,fill=id)+geom_polygon()+geom_path(color="white")+coord_equal()+scale_fill_manual(values=colset)
     grid.arrange(gC,gT,gmap,ncol=2,nrow=2)


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

# Multiple plot function
# http://www.cookbook-r.com/Graphs/Multiple_graphs_on_one_page_%28ggplot2%29/
# ggplot objects can be passed in ..., or to plotlist (as a list of ggplot objects)
# - cols:   Number of columns in layout
# - layout: A matrix specifying the layout. If present, 'cols' is ignored.
#
# If the layout is something like matrix(c(1,2,3,3), nrow=2, byrow=TRUE),
# then plot 1 will go in the upper left, 2 will go in the upper right, and
# 3 will go all the way across the bottom.
#
multiplot <- function(..., plotlist=NULL, file, cols=1, layout=NULL) {
  require(grid)

  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)

  numPlots = length(plots)

  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                    ncol = cols, nrow = ceiling(numPlots/cols))
  }

 if (numPlots==1) {
    print(plots[[1]])

  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))

    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))

      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}

