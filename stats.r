# R code to plot preliminary results for OSGeoLive 2011
# install.packages(c("RSQLite","car","spdep","rgdal","reshape","RColorBrewer")
start <- function(){
    #usage con <- start()
    require(RSQLite)
    m <- dbDriver("SQLite")
    con <- dbConnect(m, dbname = "osgeolivedata.sqlite",loadable.extensions = TRUE)
    return(con)
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
    registerDoMC(cores = 4)

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
    #opar<-par()
    par(oma=c(2,4,2,2))
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
    #note 90% of the downloads from ~45 countries
    sum(sort(downs$downloads,decreasing=TRUE)[0:45])/sum(downs$downloads)

    
    #combined Contrib+Translators, overlap removed
    combineSQL  <- 'SELECT country,count(name) as participants FROM (SELECT distinct(name),max(country) as country FROM (SELECT distinct(name),country FROM contributors UNION SELECT distinct(name),country FROM translators) GROUP BY name) GROUP BY country;'
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
    #Not appropriate to treat as contingency table    
    #fullcont(con,country.cont,of)
    #correlation test instead for non-parametric data (regression won't work here - non-normal data, no easy transform)
    cor.k = cor.test(country.cont[,1],country.cont[,2],method="kendall")
    capture.output(print(cor.s),file=of,append=TRUE)
    #Don't use Pearson's not looking for linear effect, data not normally distributed.
    cor.p = cor.test(country.cont[,1],country.cont[,2],method="pearson")
    capture.output(print(cor.p),file=of,append=TRUE)
    
    #subset only those countries with participants
    #TODO split contributors and translators
    #contribSQL <- 'SELECT country,count(name) as contributors FROM contributors as a, (SELECT max(rev) as mrev FROM "contributors") as b WHERE rev = mrev GROUP BY Country;'
    #contrib <- dbGetQuery(con,contribSQL)
    #transSQL <- 'SELECT country,count(name) as translators FROM translators as a,(SELECT max(rev) as mrev FROM "translators") as b WHERE rev = mrev GROUP BY Country;'
    #trans <- dbGetQuery(con,transSQL)
    #country.df <- merge(downs,contrib,all.x=TRUE)
    #country.df <- merge(country.df,trans,all.x=TRUE)
        
    country.part <- country.df[country.df$participants > 0,]
    country.partmatrix <- as.matrix(country.part[,-1])
    row.names(country.partmatrix) <- country.part[,1]
    country.dist <- dist(country.partmatrix)
    country.clust <- hclust(country.dist)
    
    #optional use ggplot2 based dendrogram plot with rotate
    require(ggplot2)
    require(ggdendro)
    country.dendro <- dendro_data(country.clust)
    ggdendrogram(country.dendro, rotate=TRUE)

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


