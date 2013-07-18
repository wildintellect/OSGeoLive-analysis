# R code to create infographic of OSGeoLive history
library(RSQLite)
m <- dbDriver("SQLite")
con <- dbConnect(m, dbname = "osgeolivedata.sqlite",loadable.extensions = TRUE)

q1 <- "SELECT c.rev, COUNT(name) as count,time FROM contributors as c, svnversion as v WHERE c.rev = v.rev GROUP BY c.rev"
contrib <- dbGetQuery(con,q1)
#Crude plot by revision numbering
plot(contrib$rev,contrib$count,xlab="SVN Revision Number",ylab="Count")

q2 <- "SELECT c.rev, COUNT(name) as count,time FROM translators as c, svnversion as v WHERE c.rev = v.rev GROUP BY c.rev"
trans <- dbGetQuery(con,q2)
plot(trans$rev,trans$count,xlab="SVN Revision Number",ylab="Count")

#Info by release
d4 <- dbReadTable(con,"release")

#plot showing the size of each type of release
png(file="OSGeoLiveReleases.png", width=400, height=400, units="px")
sizes <- rbind(as.numeric(d4$iso),as.numeric(d4$mini),as.numeric(d4$vm))
barplot(sizes,col=c("blue","lightblue","orange"),beside=TRUE, names.arg=d4$version,ylim=c(0,5),ylab="Size in GB",xlab="Release Number",legend=c("iso","mini","vm"))
dev.off()

#plot together
png(file="OSGeoCommitters.png", width=400, height=400, units="px")
xrange <- c(0,max(d4$rev))
yrange <- c(0,100)
colors <- c("blue","orange")
plot(xrange,yrange,type="n",xlab="SVN Revision Number",ylab="Count")
lines(contrib$rev,contrib$count,col=colors[1])
lines(trans$rev,trans$count,col=colors[2])
axis(3,at=d4$rev,labels=d4$version, las=2)
legend("topleft",legend=c("Contributors","Translators"),fill=colors)
dev.off()


dbDisconnect(con)
