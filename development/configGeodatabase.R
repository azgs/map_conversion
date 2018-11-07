#############################################################################################################
############################################## CONFIGURATION, SCRIPT ########################################
#############################################################################################################    
# Increase the timeout time and change the fancyquote settings
options(timeout=600, "useFancyQuotes"=FALSE)

# Load or install RPostgreSQL package
if (suppressWarnings(require("RPostgreSQL"))==FALSE) {
        install.packages("RPostgreSQL",repos="http://cran.cnr.berkeley.edu/");
        library("RPostgreSQL");
        } 
        
# Load or install rgdal package
if (suppressWarnings(require("rgdal"))==FALSE) {
        install.packages("rgdal",repos="http://cran.cnr.berkeley.edu/");
        library("rgdal");
        }         

# Load the command line arguments
# 1st Element = path to target geodatabase
# 2nd Element = target postgres schema
# 3rd Element = target postgres database
CommandArguments <- commandArgs(TRUE)
# Check if the appropriate number of arguments was submitted
if (length(CommandArguments)!=3) {
	stop("Must specify path to the config.gdb, the target postgres schema, and the target postgres database.")
	}

# Link to the postgres database
Connection <- dbConnect(PostgreSQL(), dbname = CommandArguments[3]) 

#############################################################################################################
############################################# GEODATABASE SCHEMA ############################################
#############################################################################################################
# Create the geodatabase schema, as of right now we are assume this schema is ncgmp09
dbSendQuery(Connection,paste("CREATE SCHEMA",CommandArguments[2]))

# Read the layers from the geodatabase
Layers<-rgdal::ogrListLayers(CommandArguments[1])
SchemaLayers<-paste(CommandArguments[2],dQuote(Layers),sep=".")

# Upload the initial "dummy" geodatabase to postgres
# Write the geodatabase to postgres
Command<-paste0('ogr2ogr -lco GEOMETRY_NAME=geom -lco LAUNDER="NO" -f "PostgreSQL" PG:"host=localhost dbname=',CommandArguments[3],' schemas=',CommandArguments[2],'" ',CommandArguments[1])
system(Command)

# Loop through and truncate all of the uploaded tables to ensure that there's no hanging data
dbSendQuery(Connection,paste("TRUNCATE",paste(SchemaLayers,collapse=","),"CASCADE;"))

# Add the collection_id field to each table.	    
for (Layer in SchemaLayers) {
	Query<-paste("ALTER TABLE",Layer,"ADD COLUMN collection_id integer REFERENCES master_table(collection_id);")
       	dbSendQuery(Connection,Query)
       	}