# R code to create infographic of OSGeoLive history
start <- function(){
    #usage con <- start()
    require(RSQLite)
    m <- dbDriver("SQLite")
    con <- dbConnect(m, dbname = "osgeolivedata.sqlite",loadable.extensions = TRUE)
    return(con)
}

#Variable scope isn't right so this function is useless for now
dataloading <- function(con){
    q1 <- "SELECT c.rev, COUNT(name) as count,time FROM contributors as c, svnversion as v WHERE c.rev = v.rev GROUP BY c.rev"
    contrib <- dbGetQuery(con,q1)
    #Crude plot by revision numbering
    #plot(contrib$rev,contrib$count,xlab="SVN Revision Number",ylab="Count")

    q2 <- "SELECT c.rev, COUNT(name) as count,time FROM translators as c, svnversion as v WHERE c.rev = v.rev GROUP BY c.rev"
    trans <- dbGetQuery(con,q2)
    #plot(trans$rev,trans$count,xlab="SVN Revision Number",ylab="Count")

#Info by release
    d4 <- dbReadTable(con,"release")
}

CommittersByDate <- function(con){
    q1 <- "SELECT c.rev, COUNT(name) as count,time FROM contributors as c, svnversion as v WHERE c.rev = v.rev GROUP BY c.rev"
    contrib <- dbGetQuery(con,q1)
    #Crude plot by revision numbering
    #plot(contrib$rev,contrib$count,xlab="SVN Revision Number",ylab="Count")

    q2 <- "SELECT c.rev, COUNT(name) as count,time FROM translators as c, svnversion as v WHERE c.rev = v.rev GROUP BY c.rev"
    trans <- dbGetQuery(con,q2)
    d4a <- dbReadTable(con,"release")
    d4 <- d4a[1:8,]
    
    xrange <- c(min(as.Date(d4$time)),max(as.Date(d4$time)+185))
    yrange <- c(0,100)
    colors <- c("blue","orange")
    plot(xrange,yrange,type="n",xlab="Date",ylab="Count")
    lines(as.Date(contrib$time),contrib$count,col=colors[1])
    lines(as.Date(trans$time),trans$count,col=colors[2])
    axis(3,at=as.Date(d4$time),labels=d4$version, las=2)
    legend("topleft",legend=c   ("Contributors","Translators"),fill=colors)
    return(colors)
}

ReleaseSizes <- function(con,colors){
    d4a <- dbReadTable(con,"release")
    d4 <- d4a[1:8,]
    sizes <- rbind(as.numeric(d4$vm),as.numeric(d4$mini),as.numeric(d4$iso))
    #get time widths of each release
    widths <- diff(c(as.Date(d4$time), max(as.Date(d4$time)+100)))
    nwidths = unlist(lapply(widths, rep,times=3 ))/3
    #plotting
    #colors <- c(gray(0.1),"lightgray","white")
    barplot(sizes,beside=TRUE, names.arg=d4  $version,ylim=c(0,6),ylab="Size in GB",xlab="Release Number",col=colors,space=c(0,.75))
    legend("topleft",legend=c("vm","mini","iso"),fill=colors,horiz=TRUE)
    #Add lines showing max size allowed for iso and mini
    linetypes = c(3,2)    
    abline(h=c(3.8,4.7),lty=linetypes,col="black")
    legend("topright",legend=c("4GB usb Limit","4.7 GB DVD Limit"),lty=linetypes,horiz=TRUE)
}

DownloadPlot <- function(con,colors){
    require(reshape)
    #Need to mark that versions 2-5.5 are not from all servers, assuming load balancing between EU and non-EU ~25%

    #q3 <- "SELECT version,type,(sum(viewed)) as downloads FROM osgeodowndata2011 GROUP BY version, type"
    #Sourceforge + Ice only data(*4)
    q3 <-"SELECT version,type,(sum(viewed))*3 as downloads FROM osgeodowndata2011 WHERE Version < 6 GROUP BY version, type UNION SELECT version,(CASE WHEN type Like '7z' Then 'vm' WHEN type Like 'iso' THEN 'full' ELSE type END) as type,(sum(downloads)) as downloads FROM sfcountries WHERE Version < 7 GROUP BY version,type"

    d5 <- dbGetQuery(con,q3)

    #get the widths of each release
    d4a <- dbReadTable(con,"release")
    d4 <- d4a[1:8,]
    widths <- diff(c(as.Date(d4a$time), max(as.Date(d4a$time))))
    #nwidths = unlist(widths)
    #reshape data for plotting
    temp <- cast(d5,version~type)
    barplot(rbind(temp[,2],temp[,3],temp[,4]),ylim=c(0,25000),names.arg=temp$version, col=rev(colors),width=as.vector(widths),space=.15,ylab="Number of Downloads",xlab="Release Number")
    legend("topleft",legend=c("vm","mini","iso"),fill=colors,horiz=TRUE)
    
    #draw a box around the estimated values
    #rect(xleft=0,ybottom=0,xright=1215,ytop=18000,angle=45,density=3,col=gray(0.65))
    rect(xleft=0,ybottom=0,xright=1215,ytop=18000,angle=45,col=gray(1,alpha=0.3),border=FALSE)
    rect(xleft=0,ybottom=0,xright=1215,ytop=18000,angle=45,col=gray(.4,alpha=0.5),density=2)

    text(x=600,y=15000,"Estimated Values",col=gray(0.2))

       
}

end <- function(con){dbDisconnect(con)}


#plot showing the size of each type of release
separatePlot <- function(con){
    #png(file="OSGeoLiveReleases.png", width=400, height=400, units="px")
    pdf(file="OSGeoLiveReleases.pdf", width=4, height=4)
    ReleaseSizes(con)    
    dev.off()
    
    # Todo: add number of applications and number of languages as axis or marks
    # By date to space out the releases better for plotting along side other data
    #png(file="OSGeoLiveCommittersByDate.png", width=400, height=400, units="px")
    pdf(file="OSGeoLiveCommittersByDate.pdf", width=4, height=4)
    CommittersByDate(con)
    dev.off()
}

#plot together
# 2 Plots stacked
stackPlot <- function(con){
    #Todo, export pdf of svg for better quality
    #png(file="OSGeoLiveInfographic.png", width=400,height=800, units="px")
    pdf(file="OSGeoLiveInfographic.pdf", width=8.5,height=11)
    par(mfrow=c(3,1))
    colors <- c(gray(0.8),gray(0.5),gray(0.2))
    ReleaseSizes(con,colors)
    DownloadPlot(con,colors)
    CommittersByDate(con)
    dev.off()
}
