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


exploreplots <- function(){
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


testRandom <- function(){
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
    downdata.rf <- randomForest(downbypop ~ economy+income+avg+uniqueip+average+peak+highbroadband+akamaibroadband+narrowband+DemIndex, data=downdata, subset=train, keep.forest=TRUE,importance = TRUE)
    importance(downdata.rf)
    
    #party might be better since its a mix of categorical(ordinal) and (interval)
    downdata.cf <- cforest(downbypop ~ economy+income+avg+uniqueip+average+peak+highbroadband+akamaibroadband+narrowband+DemIndex, data=downdata, subset=train)
    

    #Is the formula right?
    #Maybe don't need to divided downloads by population, so that forest can tell if population matters
    #uniqueip is dangerous since number of ip's is highly controlled, and early adopters have larger share - maybe this makes it a good measure?
    downdata.cf <- cforest(downloads ~ pop+economy+income+average+peak+highbroadband+akamaibroadband+narrowband+DemIndex+itubroadband, data=downdata, subset=train)
    
    #Try to figure out which variables are important, conditional means assume the variables are correlated
    downdata.varimp <- varimp(downdata.cf, conditional=TRUE)

    #Plot with a line at the abs(of the biggest negative)
    #http://www.stanford.edu/~stephsus/R-randomforest-guide.pdf
    par(oma=c(2,4,2,2))
    barplot(sort(downdata.varimp),horiz=TRUE, las=1)
    abline(v=abs(min(downdata.varimp)), col='red',lty='longdash', lwd=2)

    require(corrgram)
    corrgram(downdata, order=TRUE, lower.panel=panel.shade,  upper.panel=panel.pie, text.panel=panel.txt,  main="OSGeo Download, PCA ordered") 

       
}


OSanalysis <- function(){
    require(Deducer)

    #Two nominal variables - County and Operating System
    #http://udel.edu/~mcdonald/statgtestind.html
    downbyos <- dbReadTable(con,"TotDownByOs")
    compbyos <- c(92.02,6.81,1.16,0.00)
    downbyos.mat <- as.matrix(downbyos[1,-1]/sum(downbyos[1,-1])*100)
    downbyos.cont <- rbind(downbyos.mat,compbyos)
    row.names(downbyos.cont) <- c("downloads","computers")      
    chisq.test(downbyos.cont)
    likelihood.test(downbyos.cont)
    #	Pearson's Chi-squared test
    #data:  downbyos.cont
    #X-squared = 25.4531, df = 3, p-value = 1.241e-05

    #Summary information
    #Convert to percentages, calculate min, max, avg, std_dev by column


    #Contigency analysis of Type of Download by OS of Downloader 
    typebyos <- dbReadTable(con,"TypeByOS")
    typebyos.cont <- as.matrix(as.integer(typebyos[,-1]))
    row.names(typebyos.cont) <- typebyos[,1]
    likelihood.test(typebyos)

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
    country.df <- merge(country.cont,trans,all.x=TRUE)
    #Replace NA with 0
    country.df[is.na(country.df)] <- 0
    #Convert to martix contingency table
    country.cont <- as.matrix(country.df[,-1])
    row.names(country.cont) <- country.df[,1]
    likelihood.test(country.cont)

    #Log likelihood ratio (G-test) test of independence without correction
    #data:  country.cont
    #Log likelihood ratio statistic (G) = 367.4859, X-squared df = 320,
    #p-value = 0.03457

    #Contingency analysis of Countries By OS variation
    # the tails of Windows use(none/100) seem to have something in common
    countrybyos <- dbReadTable(con,"CountryByOS")
    countrybyos.cont <- as.matrix(countrybyos[,-1])
    row.names(countrybyos.cont) <- countrybyos[,1]
    likelihood.test(countrybyos.cont)
    
    #Log likelihood ratio (G-test) test of independence without correction
    #data:  countrybyos.cont
    #Log likelihood ratio statistic (G) = 10848.92, X-squared df = 480,
    #p-value < 2.2e-16
    
}

fancyplot <- function(){
    require(RColorBrewer)
    #Get a List of the release dates and versions
    d1 <- dbReadTable(con,"release")
    #d2 <- dbReadTable(con,"ContribRegion")
    d2sql <- "SELECT release,subregion,sum(count) as count FROM ContribRegion GROUP BY release,subregion"    
    d2 <- dbGetQuery(con,d2sql)

    #d3sql <- "SELECT release,subregion,sum(count) as Tcount FROM TransRegion GROUP BY release,subregion"    
    #d3 <- dbGetQuery(con,d3sql)
    d3 <- dbReadTable(con,"TransRegion")
    
    #Contrib plot
    d2t <-xtabs(count~subregion+release,data=d2)

    colset <- brewer.pal(9,"Set1")
    barplot(d2t,col=colset)
    legend("topleft",legend=rownames(d2t),fill=colset)

    #Trans plot - TODO merge somehow with contrin plot
    d3t <-xtabs(count~subregion+release,data=d3)

    colset <- brewer.pal(9,"Set1")
    barplot(d3t,col=colset)
    legend("topleft",legend=rownames(d3t),fill=colset)

    #get total number of releases
    cnt <- length(d1)


    #Query returns count of people per country per release
    d2 <- "SELECT release,subregion,sum(count) as count FROM ContribRegion GROUP BY release,subregion"



    #Setup a stacked set of plots
    #row 1, map by version
    #row 2, downloads by region - barplot
    #row 3, line graph of contributors and translators
    #ltest <- rbind(seq(1,7),rep(8,7),rep(9,7))
    #dynamic version
    ltest <- rbind(seq(1,cnt),rep(cnt+1,cnt),rep(cnt+2,cnt))
    nf <- layout(ltest)
    layout.show(nf)
}
