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



