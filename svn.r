# R code to create infographic of OSGeoLive history
library(RSQLite)
m <- dbDriver("SQLite")
con <- dbConnect(m, dbname = "osgeolivedata.sqlite",loadable.extensions = TRUE)
