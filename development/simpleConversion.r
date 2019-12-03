if (suppressWarnings(require("sf"))==FALSE) {
    install.packages("sf",repos="http://cran.cnr.berkeley.edu/");
    library("sf");
    }

# Load the command line arguments
# 1st Element = path to target geodatabase
# 2nd Element = path to output directory
CommandArguments<-subset(commandArgs(TRUE),substring(commandArgs(TRUE),1,2)!="--")
# Check if the appropriate number of arguments was submitted
if (length(CommandArguments)<2) {
	stop("Must specify path to the geodatabase, path to output directory")
	}

# Get the color vector from QueryPolys
getColors<-function(QueryPolys) {
        color<-sapply(QueryPolys$AreaFillRGB,strsplit,";")
        color<-sapply(color,function(x) rgb(as.numeric(x[1]),as.numeric(x[2]),as.numeric(x[3]),maxColorValue=255))
        return(color)
        }

# A function to export any tables (with data and geometries) as a format specificed from the command line
simpleConversion<-function(Input=CommandArguments[1],Output=CommandArguments[2]) {
        # Get a list of layers
        polys = sf::st_read(dsn=Input,layer="MapUnitPolys")
        polys = sf::st_transform(polys,4326) # hardcode in the wgs84
        description = sf::st_read(dsn=Input,layer="DescriptionOfMapUnits",stringsAsFactors=FALSE)
        description = description[,c("MapUnit","Description","Age","AreaFillRGB","GeneralLithology")]
        join = merge(polys,description,by="MapUnit",all.x=TRUE)
        # Remove polys without color
        join<-subset(join,is.na(join$AreaFillRGB)!=TRUE)
        join$OGR_STYLE<-getColors(join)
        for (format in c("shp","geojson")) {
            sf::st_write(join,paste0(Output,"/","MapUnitPolys",".",format),delete_dsn=TRUE)
            }
        join$OGR_STYLE<-paste0("BRUSH(fc:",join$OGR_STYLE,");(PEN(c:#000000,w:1px)")
        sf::st_write(join,paste0(Output,"/MapUnitPolys.kml"),driver="libkml",delete_dsn=TRUE)
        }

simpleConversion(CommandArguments[1],CommandArguments[2])