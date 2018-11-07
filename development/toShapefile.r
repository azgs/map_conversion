
# Methods and Functions are camelCase. Variables and Data Structures are PascalCase
# Fields generally follow snake_case for better SQL compatibility
# Dependency functions are not embedded in master functions
# []-notation is used wherever possible, and $-notation is avoided.
# []-notation is slower, but more explicit and works for atomic vectors

#############################################################################################################
############################################## CONFIGURATION, SCRIPT ########################################
#############################################################################################################    
# Increase the timeout time and change the fancyquote settings
options(timeout=600, "useFancyQuotes"=FALSE)

# Load or install RPostgreSQL package
if (suppressWarnings(require("sf"))==FALSE) {
        install.packages("sf",repos="http://cran.cnr.berkeley.edu/");
        library("sf");
        } 
        
# Load the command line arguments
# 1st Element = path to target geodatabase
# 2nd Element = path to output directory
# Check if the appropriate number of arguments was submitted
CommandArguments<-commandArgs(TRUE)
if (length(CommandArguments)<2) {
	stop("Must specify path to the geodatabase and path to output directory")
	}

#############################################################################################################
############################################## EXPORT SHP FUNCTIONS #########################################
#############################################################################################################
# Merge the polygon layers together
mergePolys<-function(Input=CommandArguments[1]) {
        # Read in the available layers from gdb
        Layers<-sf::st_layers(Input)
        if (!all(c("MapUnitPolys","DescriptionOfMapUnits")%in%Layers$name[which(Layers$features>0)])) {
                stop("MapUnitPolys or DescriptionOfMapUnits table is missing or empty")
                }
        # Load the Polygon layers in
        MapUnitPolys<-sf::st_read(Input,"MapUnitPolys",quiet=TRUE)
        DescriptionOfMapUnits<-sf::st_read(Input,"DescriptionOfMapUnits",quiet=TRUE)
        # Eliminate duplicate columns, note that the order of objects in setdiff( ) matters
        Uniques<-setdiff(colnames(DescriptionOfMapUnits),colnames(MapUnitPolys))
        # Do a left join of MapUnitPOlys with Description of MapUnits
        MapUnitPolys<-merge(MapUnitPolys,DescriptionOfMapUnits[,c("MapUnit",Uniques)],by="MapUnit",all.x=TRUE)
        return(MapUnitPolys)
        }

# Merge the lines layers together
mergeLines<-function(Input=CommandArguments[1]) {
        # Read in the available layers from gdb
        Layers<-sf::st_layers(Input)
        if (!all(c("ContactsAndFaults","Glossary")%in%Layers$name[which(Layers$features>0)])) {
                stop("ContactsAndFaults or Glossary table is missing or empty")
                }
        ContactsAndFaults<-sf::st_read(Input,"ContactsAndFaults",quiet=TRUE)
        Glossary<-sf::st_read(Input,"Glossary",quiet=TRUE)
        # Check if the Type and Term fields match according to NCGMP09 specification
        if (any(Check<-(unique(ContactsAndFaults$Type)%in%Glossary$Term!=TRUE))) {
                print(unique(ContactsAndFaults$Type)[which(Check)])
                stop("ContactsAndFaults type(s) are not in Glossary")
                }
        # Do a left join of ContactsAndFaults with MapUnits
        ContactsAndFaults<-merge(ContactsAndFaults,Glossary,by.x="Type",by.y="Term",all.x=TRUE)
        return(ContactsAndFaults)
        }

# Merge the points layers together
mergePoints<-function(Input=CommandArguments[1]) {
        # Read in the available layers from gdb
        Layers<-sf::st_layers(Input)
        Layers<-Layers$name[which(Layers$features>0)]
        if ("OrientationPoints"%in%Layers!=TRUE) {
                warning("OrientationPoints table is empty or missing");
                return(NA)
                }
        else if ("Glossary"%in%Layers!=TRUE) {
                stop("Glossary table is missing or empty")
                }
        OrientationPoints<-sf::st_read(Input,"OrientationPoints",quiet=TRUE)
        Glossary<-sf::st_read(Input,"Glossary",quiet=TRUE)
        # Check if the Type and Term fields match according to NCGMP09 specification
        if (any(Check<-(unique(OrientationPoints$Type)%in%Glossary[,"Term"]!=TRUE))) {
                print(unique(OrientationPoints$Type)[which(Check)])
                stop("OrientationPoints type(s) are not in Glossary")
                }
        # Do a left join of ContactsAndFaults with MapUnits
        OrientationPoints<-merge(OrientationPoints,Glossary,by.x="Type",by.y="Term",all.x=TRUE)
        return(OrientationPoints)
        }

# Write the results out to to the target folder
writeLayers<-function(Input=CommandArguments[1],Output=CommandArguments[2]) {
        sf::st_write(mergePolys(Input),paste(Output,"MapUnitPolys",sep="/"),delete_dsn=TRUE,driver="ESRI Shapefile")
        sf::st_write(mergeLines(Input),paste(Output,"ContactsAndFaults",sep="/"),delete_dsn=TRUE,driver="ESRI Shapefile")
        Points<-mergePoints(Input)
        if (is.na(Points)) {
                return(print("All layers exported to shapefile"))
                }
        else {
                sf::st_write(Points,paste(Output,"OrientationPoints",sep="/"),delete_dsn=TRUE,driver="ESRI Shapefile")
                }
        print("All layers exported to shapefile")
        }

zipDir<-function(Output=CommandArguments[2]) {
        # Store the original working directory
        Original<-getwd()
        setwd(CommandArguments[2])
        zip(paste0(CommandArguments[2],".zip"),files=dir(CommandArguments[2]),flags="-rm")
        setwd(Original)
        unlink(CommandArguments[2],recursive=TRUE)
        }

################################################ EXPORT SHAPE SCRIPT ########################################
# Excute the script
writeLayers(CommandArguments[1],CommandArguments[2])

# Zip the output
zipDir(CommandArguments[2])