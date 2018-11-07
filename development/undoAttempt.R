
# Custom functions are camelCase. Arrays and Arguments are PascalCase

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
   
# Load the command line argument
# 1st Element = attempt_id to be removed
CommandArguments <- commandArgs(TRUE)
# Check if the appropriate number of arguments was submitted
if (length(CommandArguments)!=2) {
	stop("Must specify an attempt to undo and a target postgres database.")
	}

# Link to the postgres database
Connection <- dbConnect(PostgreSQL(), dbname = CommandArguments[2]) 

#############################################################################################################
############################################## ROLLBACK, SCRIPT #############################################
#############################################################################################################
# Removes all rows from all tables corresponding to an attempt_id, except the master_table
Layers<-dbGetQuery(Connection,"SELECT table_name FROM information_schema.tables WHERE table_schema='map_layers';")[,1]
SchemaLayers<-paste("map_layers",dQuote(Layers),sep=".")

# Add the gdb_name field to each table.	    
for (Layer in SchemaLayers) {
	Query<-paste("DELETE FROM",Layer,"WHERE attempt_id =",sQuote(CommandArguments[1]))
       	dbSendQuery(Connection,Query)
       	}
        
# Update the master_table to indicate it was removed
Query<-paste("UPDATE master_table SET removed = 'TRUE' WHERE attempt_id =",sQuote(CommandArguments[1]))
dbSendQuery(Connection,Query)

# Disconnect from PostgreSQL
dbDisconnect(Connection)