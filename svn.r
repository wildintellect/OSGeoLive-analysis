# R code to create infographic of OSGeoLive history
start <- function(){
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
    d4 <- dbReadTable(con,"release")
    
    xrange <- c(min(as.Date(d4$time)),max(as.Date(d4$time)+100))
    yrange <- c(0,100)
    colors <- c("blue","orange")
    plot(xrange,yrange,type="n",xlab="Date",ylab="Count")
    lines(as.Date(contrib$time),contrib$count,col=colors[1])
    lines(as.Date(trans$time),trans$count,col=colors[2])
    axis(3,at=as.Date(d4$time),labels=d4$version, las=2)
    legend("topleft",legend=c   ("Contributors","Translators"),fill=colors)
}

ReleaseSizes <- function(con,colors){
    d4 <- dbReadTable(con,"release")
    sizes <- rbind(as.numeric(d4$iso),as.numeric(d4$mini),as.numeric(d4$vm))
    #get time widths of each release
    widths <- diff(c(as.Date(d4$time), max(as.Date(d4$time)+100)))
    nwidths = unlist(lapply(widths, rep,times=3 ))/3
    #plotting
    #colors <- c(gray(0.1),"lightgray","white")
    barplot(sizes,beside=TRUE, names.arg=d4  $version,ylim=c(0,6),ylab="Size in GB",xlab="Release Number",col=colors)
    legend("topleft",legend=c("iso","mini","vm"),fill=colors,horiz=TRUE)
}

DownloadPlot <- function(con,colors){
    require(reshape)
    q3 <- "SELECT version,type,(sum(viewed)) as downloads FROM osgeodowndata2011 GROUP BY version, type"
    d5 <- dbGetQuery(con,q3)
    #get the widths of each release
    d4 <- dbReadTable(con,"release")
    widths <- diff(c(as.Date(d4$time), max(as.Date(d4$time)+100)))
    #nwidths = unlist(widths)
    #reshape data for plotting
    temp <- cast(d5,version~type)
    barplot(rbind(temp[,2],temp[,3],temp[,4]),ylim=c(0,6000),names.arg=temp$version, col=colors,width=as.vector(widths),space=.15,ylab="Number of Downloads",xlab="Release Number")
    legend("topleft",legend=c("iso","mini","vm"),fill=colors,horiz=TRUE)

}

end <- function(con){dbDisconnect(con)}


#plot showing the size of each type of release
separatePlot <- function(con){
    png(file="OSGeoLiveReleases.png", width=400, height=400, units="px")
    ReleaseSizes(con)    
    dev.off()
    
    # Todo: add number of applications and number of languages as axis or marks
    # By date to space out the releases better for plotting along side other data
    png(file="OSGeoLiveCommittersByDate.png", width=400, height=400, units="px")
    CommittersByDate(con)
    dev.off()
}

#plot together
# 2 Plots stacked
stackPlot <- function(con){
    png(file="OSGeoLiveInfographic.png", width=400,height=600, units="px")
    par(mfrow=c(3,1))
    colors <- c(gray(0.2),gray(0.5),gray(0.8))
    ReleaseSizes(con,colors)
    DownloadPlot(con,colors)
    CommittersByDate(con)
    dev.off()
}
