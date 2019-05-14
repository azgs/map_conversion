
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
# 3rd Element and beyond = Formats (e.g., shp, geojson, kml)
# --tables = Will also export tables as CSV
Flags<-subset(commandArgs(TRUE),substring(commandArgs(TRUE),1,2)=="--")
if (length(Flags)==0) {Flags<-FALSE}
CommandArguments<-subset(commandArgs(TRUE),substring(commandArgs(TRUE),1,2)!="--")
# Check if the appropriate number of arguments was submitted
if (length(CommandArguments)<3) {
	stop("Must specify path to the geodatabase, path to output directory, and 1 or more formats")
	}

#############################################################################################################
############################################ EXPORT GEOMS FUNCTIONS #########################################
#############################################################################################################
# A function to export any tables (with data and geometries) as a format specificed from the command line
exportGeoms<-function(Input=CommandArguments[1],Output=CommandArguments[2],Format=CommandArguments[3]) {
        # Get a list of layers
        Layers<-sf::st_layers(Input)
        # Separate out the layers with geometries and those without
        # Also exclude any tables or layers without features
        Geometries<-Layers$name[which(is.na(unlist(Layers$geomtype))!=TRUE & Layers$features>0)]
        # Loop through and export each layer to the desired format and Output directory
        for (Layer in Geometries) {
	        # Read a layer in
                Read<-sf::st_read(Input,Layer)
                # Convert to 4326... ALWAYS
                Read<-sf::st_transform(Read,4326)
                # Name the layer, attach path to output directory
                Conversion<-paste0(Output,"/",Layer,".",Format)
                sf::st_write(Read,Conversion)
                print(paste(Layer,"successfully exported")) # show which layers were written
                }
        }

################################################ EXPORT GEOMS SCRIPT ########################################
Formats<-CommandArguments[3:length(CommandArguments)]
for (i in seq_along(Formats)) {
        print(paste("Now exporting",Formats[i],"files"))
        exportGeoms(CommandArguments[1],CommandArguments[2],Formats[i])
        }

#############################################################################################################
############################################ EXPORT TABLES FUNCTIONS ########################################
#############################################################################################################
# A function to export any tables (with data and no geoms) as csv.
exportTables<-function(Input=CommandArguments[1],Output=CommandArguments[2]) {
        # Get a list of layers
        Layers<-sf::st_layers(Input)
        # Separate out the layers with geometries and those without
        # Also exclude any tables or layers without features
        Tables<-Layers$name[which(is.na(unlist(Layers$geomtype)) & Layers$features>0)]
        for (Layer in Tables) {
                # Read a layer in, I suppress the warnings since these are non-geom tables
                Read<-suppressWarnings(sf::st_read(CommandArguments[1],Layer))
                # Name the layer
                Comma<-paste0(CommandArguments[2],"/",Layer,".csv")
                # Store the table to the output directory
                write.csv(Read,Comma)
                }
        }

################################################ EXPORT TABLES SCRIPT #######################################
if ("--tables"%in%Flags==TRUE) {
        exportTables(CommandArguments[1],CommandArguments[2])
        }