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
    #require(randomForest)
    #require(ROCR)
    require(party)
    #downdata <-dbReadTable(con,"Metrics2012wDemIndex")
    # Filter out null ITU
    dsql <- 'SELECT * FROM "Metrics2012wDemIndex" WHERE ITUbroadband IS NOT NULL'
    downdata <- dbGetQuery(con,dsql)
    
    #economy and income should probably be factors
    downdata$economy <- as.factor(downdata$economy)
    downdata$income <- as.factor(downdata$income)
    #Set the seed, same seed = same random selection
    #split the data into training and test data, 1/2 - use 75% of data for training 25% for testing
    #train = sample(1:nrow(downdata),nrow(downdata)/2)
    train = sample(1:nrow(downdata),floor(nrow(downdata)*.75))

    #build a random forest regression
    #mtry default is p/3 unless doing bagging
    #ntree can be change
    #Potentially use tuneRF to find the mtry and ntree values to use
    # itu-broadband had nulls values
    #downdata.rf <- randomForest(downbypop ~ economy+income+ooklaaverage+akuniqueip+akaverage+akpeak+akhighbroadband+akbroadband+aknarrowband+DemIndex, data=downdata, subset=train, keep.forest=TRUE,importance = TRUE)
    #importance(downdata.rf)
    
    #party might be better since its a mix of categorical(ordinal) and (interval)
    #party is supposed to be better for highly correlated data (see papers)
    #ITU has 2 NA, count as zero?
    #downdata[is.na(downdata)] <- 0
    downdata.cf <- cforest(downbypop ~ economy+income+OoklaAverage+ITUbroadband+AkUniqueIP+AkAverage+AkPeak+AkHighBroadband+AkBroadband+AkNarrowband+DemIndex, data=downdata, subset=train, control = cforest_unbiased(ntree = 1000))
    #downdata.cf <- cforest(downbypop ~ economy+income+OoklaAverage+ITUbroadband+AkUniqueIP+AkAverage+AkPeak+AkHighBroadband+AkBroadband+AkNarrowband+DemIndex, data=downdata)

    #Is the formula right?
    #Maybe don't need to divided downloads by population, so that forest can tell if population matters
    #uniqueip is dangerous since number of ip's is highly controlled, and early adopters have larger share - maybe this makes it a good measure?
    
    #Population is a big driver, is it better to just multiply downbypop*100? to make it more readable
    #downdata.cf <- cforest(downloads ~ pop+economy+income+average+peak+highbroadband+akamaibroadband+narrowband+DemIndex+itubroadband, data=downdata, subset=train)
    
    #Try to figure out which variables are important, conditional means assume the variables are correlated
    downdata.varimp <- varimp(downdata.cf, conditional=TRUE)

    #save results to file, nothing useful to save?
    of <- "ForestResults.txt"
    capture.output(print(downdata.cf),file=of,append=FALSE)

    #Plot with a line at the abs(of the biggest negative)
    #http://www.stanford.edu/~stephsus/R-randomforest-guide.pdf
    pdf(file="ImportantVariables-notrain.pdf",width=6,height=8)
    opar<-par()
    par(oma=c(2,4,2,2))
    barplot(sort(downdata.varimp),horiz=TRUE, las=1,xlab="")
    abline(v=abs(min(downdata.varimp)), col='red',lty='longdash', lwd=2)
    dev.off()
    par(opar)

    #For testing get the inverse of the training data
    testdata <- downdata[-train,]

    require(corrgram)
    pdf(file="CorrelationMatrix.pdf",width=6,height=6)
    corrgram(downdata, order=TRUE, lower.panel=panel.shade,  upper.panel=panel.pie, text.panel=panel.txt,  main="OSGeo Download, PCA ordered") 
    dev.off()

    require(car)
    pdf(file="ScatterPlotMatrix.pdf",width=11,height=8.5)
    scatterplotMatrix(economy+income+OoklaAverage+ITUbroadband+AkUniqueIP+AkAverage+AkPeak+AkHighBroadband+AkBroadband+AkNarrowband+DemIndex,data=downdata)
    dev.off()

    #Posthoc testing
    #http://stats.stackexchange.com/questions/77290/does-party-package-in-r-provide-out-of-bag-estimates-of-error-for-random-forest
    require(caret)
    require(parallel)
    ooberror <- caret:::cforestStats(downdata.cf)

    #Save the model error estimates
    capture.output(print(ooberror),file=of,append=TRUE)
    
}

caretForest <- function(con){

    #Set the seed to the psuedo random number generator for repeatable results
    set.seed(10)
    #require(randomForest)
    #require(ROCR)
    require(party)
    require(caret)
    require(parallel)
    require(doMC) #caret can be done in parrallel
    registerDoMC(cores = 2)

    #downdata <-dbReadTable(con,"Metrics2012wDemIndex")
    # Filter out null ITU
    dsql <- 'SELECT * FROM "Metrics2012wDemIndex" WHERE ITUbroadband IS NOT NULL'
    downdata <- dbGetQuery(con,dsql)

    #Stratified random sampling - didn't really work 
    #inTrain <- createDataPartition(downdata$downbypop,p=0.8,list=FALSE)

    #Setup the Caret model with cforest
    mod1 <- train(downbypop ~ economy+income+OoklaAverage+ITUbroadband+AkUniqueIP+AkAverage+AkPeak+AkHighBroadband+AkBroadband+AkNarrowband+DemIndex, data = downdata,method = "cforest",trControl = trainControl(method = "oob",allowParallel = TRUE, number = 10, repeats = 10),controls = cforest_unbiased(ntree = 10000))

    #When doing more than 1 at a time turn off parallel
    #mod1 <- train(downbypop ~ economy+income+OoklaAverage+ITUbroadband+AkUniqueIP+AkAverage+AkPeak+AkHighBroadband+AkBroadband+AkNarrowband+DemIndex, data = downdata,method = "cforest",trControl = trainControl(method = "oob",allowParallel = FALSE, number = 10, repeats = 10),controls = cforest_unbiased(ntree = 10000))

    test.varimp <- varimp(mod1$finalModel,conditional=TRUE)
    
    
    #Plot important variables
    pdf(file="ImportantVariables-caret.pdf",width=6,height=8)
    opar<-par()
    #par(oma=c(2,4,2,2))
    barplot(sort(test.varimp),horiz=TRUE,las=1,xlab="")
    abline(v=abs(min(test.varimp)), col='red',lty='longdash', lwd=2)
    dev.off()
    #par(opar)

    of <- "CaretCForestResults.txt"
    capture.output(print(mod1),file=of,append=FALSE)
    capture.output(print(test.varimp),file=of,append=TRUE)

    #What it does when DemIndex is dropped
    mod2 <- train(downbypop ~ economy+income+OoklaAverage+ITUbroadband+AkUniqueIP+AkAverage+AkPeak+AkHighBroadband+AkBroadband+AkNarrowband, data = downdata,method = "cforest",trControl = trainControl(method = "oob",allowParallel = TRUE, number = 10, repeats = 10),controls = cforest_unbiased(ntree = 10000))

    test.varimp2 <- varimp(mod2$finalModel,conditional=TRUE)
    of <- "CaretCForestResults.txt"
    capture.output(print(mod2),file=of,append=TRUE)
    capture.output(print(test.varimp2),file=of,append=TRUE)

    pdf(file="ImportantVariables-NoDemIndex.pdf",width=6,height=8)
    #opar<-par()
    par(oma=c(2,4,2,2))
    barplot(sort(test.varimp2),horiz=TRUE,las=1,xlab="")
    abline(v=abs(min(test.varimp2)), col='red',lty='longdash', lwd=2)
    dev.off()
    #par(opar)

}

OSanalysis <- function(con){
    #require(Deducer)
    #require(polytomous)
    require(reshape2)
    #file to hold output of tests
    #of <- "ContingencyResults.txt"
    #capture.output(print(date()),file=of,append=FALSE)

    #Two nominal variables - Country and Operating System
    #http://udel.edu/~mcdonald/statgtestind.html
    of <- "TotDownByOs.txt"
    downbyos <- dbReadTable(con,"TotDownByOs")
    compbyos <- c(92.02,6.81,1.16,0.00)
    downbyos.mat <- as.matrix(downbyos[1,-1]/sum(downbyos[1,-1])*100)
    downbyos.cont <- rbind(downbyos.mat,compbyos)
    row.names(downbyos.cont) <- c("downloads","computers")      
    #chisq.test(downbyos.cont)
    #downbyos.lt <- likelihood.test(downbyos.cont)
    #capture.output(print(downbyos.lt),file=of,append=TRUE)
    fullcont(con,downbyos.cont,of)
    #	Pearson's Chi-squared test
    #data:  downbyos.cont
    #X-squared = 25.4531, df = 3, p-value = 1.241e-05

    #Summary information
    #Convert to percentages, calculate min, max, avg, std_dev by column


  
    
    #Contingency analysis of Countries by Downloads, Contributors and Translators
    of <- "CountryCont.txt"
    ### Disabling separate columns in favor of combined
    downsSQL <- 'SELECT "country", sum(total) as downloads FROM "sfosbycountry" WHERE Version <= 6.5 GROUP BY country ORDER BY country;'
    downs <- dbGetQuery(con,downsSQL)
    #contribSQL <- 'SELECT country,count(name) as contributors FROM contributors as a, (SELECT max(rev) as mrev FROM "contributors") as b WHERE rev = mrev GROUP BY Country;'
    #contrib <- dbGetQuery(con,contribSQL)
    #transSQL <- 'SELECT country,count(name) as translators FROM translators as a,(SELECT max(rev) as mrev FROM "translators") as b WHERE rev = mrev GROUP BY Country;'
    #trans <- dbGetQuery(con,transSQL)
    
    #combined Contrib+Translators, overlap removed
    combineSQL  <- 'SELECT country,count(name) FROM (SELECT distinct(name),max(country) as country FROM (SELECT distinct(name),country FROM contributors UNION SELECT distinct(name),country FROM translators) GROUP BY name) GROUP BY country;'
    #TODO limit by version
    combined <- dbGetQuery(con,combineSQL) 
    
    #country.df <- merge(downs,contrib,all.x=TRUE)
    #country.df <- merge(country.df,trans,all.x=TRUE)
    country.df <- merge(downs,combined,all.x=TRUE)
    #Replace NA with 0
    country.df[is.na(country.df)] <- 0
    #Convert to martix contingency table
    country.cont <- as.matrix(country.df[,-1])
    row.names(country.cont) <- country.df[,1]
    #country.lt <- likelihood.test(country.cont)
    #capture.output(print(country.lt),file=of,append=TRUE)
    fullcont(con,country.cont,of)
    #Posthoc correlation test, or should it be a correlation test instead of a g-test?
    cor.k = cor.test(country.cont[,1],country.cont[,2],method="kendall")
    capture.output(print(cor.s),file=of,append=TRUE)
    #Don't use Pearson's not looking for linear effect, data not normally distributed.
    cor.p = cor.test(country.cont[,1],country.cont[,2],method="pearson")
    capture.output(print(cor.p),file=of,append=TRUE)
    
    

    #Contingency analysis of Countries By OS variation
    # the tails of Windows use(none/100) seem to have something in common
    of <- "CountryByOS.txt"
    countrybyos <- dbReadTable(con,"CountryByOS")
    countrybyos.cont <- as.matrix(countrybyos[,-1])
    row.names(countrybyos.cont) <- countrybyos[,1]
    #countrybyos.lt <- likelihood.test(countrybyos.cont)
    #capture.output(print(countrybyos.lt),file=of,append=TRUE)
    fullcont(con,countrybyos.cont,of)
    countrymelt <- melt(countrybyos)
    pdf(file="CountryOSVariation.pdf",width=6,height=8)
    #opar<-par()
    boxplot(value~variable,data=countrymelt,ylab="Percentage of Downloaders")
    dev.off()
    #par(opar)


    #Contigency analysis of Type of Download by OS of Downloader 
    of <- "TypeByOs.txt"
    typebyos <- dbReadTable(con,"TypeByOS")
    typebyos.cont <- as.matrix((typebyos[,-1]))
    row.names(typebyos.cont) <- typebyos[,1]
    typebyos.trans <- t(typebyos.cont)
    #typebyos.lt <- likelihood.test(typebyos.trans)
    #capture.output(print(typebyos.trans),file=of,append=FALSE)
    #capture.output(print(typebyos.lt),file=of,append=TRUE)
    fullcont(con,typebyos.trans,of)
    
}

fullcont <- function(con,cont,of){
    #Function runs chisq, g-test and posthoc tests on contingency tables
    require(polytomous)
    require(vcd)
    require(Deducer)
    
    capture.output(print(date()),file=of,append=FALSE)
    capture.output(print(cont),file=of,append=TRUE)
    #Standard Chi square
    cont.chi <- chisq.test(cont)
    capture.output(print(cont.chi),file=of,append=TRUE)

    #Standard Posthoc
    cont.post <- chisq.posthoc(cont)
    capture.output(print(cont.post),file=of,append=TRUE)

    #Gstat
    cont.like <- likelihood.test(cont)
    capture.output(print(cont.like),file=of,append=TRUE)

    #percent deviation
    cont.dev <- ((cont-cont.chi$expected)/cont.chi$expected)*100
    capture.output(print(cont.dev),file=of,append=TRUE)
    
    #Residuals - contributions to the solution
    #capture.output(print(cont.chi$residuals),file=of,append=TRUE)

    #Posthoc tests on Chisq, includes G2 stat too
    cont.a <- associations(cont)
    capture.output(print(cont.a),file=of,append=TRUE)
    cont.b <- assocstats(cont)
    capture.output(print(cont.b),file=of,append=TRUE)
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

    opar <- par()
    par(mar=c(0,0,0,0)) 
    plot(0, 0, type = "n", bty = "n", xaxt = "n", yaxt = "n",ann=FALSE)
    legend("top",legend=names(colset),fill=colset,cex=1.25)

    par(mar=c(2,0,0,2)) 
    plot(nesregion,col="white",bg="gray")
    plot(nesregion.filter,col=colset,add=TRUE)  
    dev.off()    

    par <- opar
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

