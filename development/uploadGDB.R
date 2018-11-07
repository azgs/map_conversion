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

# Load the command line arguments
# 1st Element = path to target geodatabase
# 2nd Element = target postgres database
# 3rd Element = geodatabase alias
# --force = Allows you to write to the database even if there might be duplicate data
Flags<-subset(commandArgs(TRUE),substring(commandArgs(TRUE),1,2)=="--")
if (length(Flags)==0) {Flags<-FALSE}
CommandArguments<-subset(commandArgs(TRUE),substring(commandArgs(TRUE),1,2)!="--")
# Check if the appropriate number of arguments was submitted
if (length(CommandArguments)!=3) {
	stop("Must specify path to target geodatabase, target postgres database, and the informal geodatabase name")
	}

# Link to the postgres database
Connection<-dbConnect(PostgreSQL(), dbname = CommandArguments[2]) 

#############################################################################################################
######################################### CHECK FOR DUPLICATION, SCRIPT #####################################
#############################################################################################################   
# Create a "unique" gdb_name by combining the gdb name with the date
gdb_name<-paste(CommandArguments[3],Sys.Date(),sep="_")
sys_time<-paste(Sys.time(),Sys.timezone())

# Upload the master table, would be faster to put this on the postgres rather than R side
# master_names<-dbGetQuery(Connection,"SELECT gdb_name FROM master_table;")[,1]
# Throw an error if a duplicate gdb_name is found
# if (gdb_name%in%master_names & Flags!="--force") {
#	stop("Logs indicate previous attempts to upload the same geodatabase or another geodatabase with the same name. Please check the database to ensure you are not entering duplicate data. To force data entry, use --force.")
#	}

# Record the attempt to write to the database in the master_table
master_matrix<-matrix(c(gdb_name,CommandArguments[3],CommandArguments[1],sys_time,"failed"),nrow=1,ncol=5)
colnames(master_matrix)<-c("gdb_name","gdb_alias","gdb_path","attempt_time","upload_status")
dbWriteTable(Connection,"master_table",as.data.frame(master_matrix),append=TRUE,row.names=FALSE)
# Extract the attempt_id assigned by postgres
AttemptID<-dbGetQuery(Connection,paste0("SELECT attempt_id FROM master_table WHERE attempt_time=",sQuote(sys_time)))

#############################################################################################################
################################################# UPLOAD, SCRIPT ############################################
#############################################################################################################   
# Write the geodatabase to postgres
Command<-paste0('ogr2ogr -append -update -f "PostgreSQL" PG:"dbname=',CommandArguments[2],' schemas=map_layers" ',CommandArguments[1])
system(Command)

# Add the unique gdb_name to each relevant row of each table in the postgres database
Tables<-dbGetQuery(Connection,"SELECT table_name FROM information_schema.tables WHERE table_schema = 'map_layers';")[,1]
SchemaTables<-paste("map_layers",dQuote(Tables),sep=".")
for (Name in SchemaTables) {
	Query<-paste("UPDATE",Name,"SET gdb_name = ",sQuote(gdb_name),"WHERE gdb_name IS NULL;")
	dbSendQuery(Connection,Query)
	Query<-paste("UPDATE",Name,"SET attempt_id = ",sQuote(AttemptID),"WHERE attempt_id IS NULL;")
	dbSendQuery(Connection,Query)
	}

# Update the master_table to record the success
Query<-paste("UPDATE master_table SET upload_status = 'success' WHERE attempt_id =",sQuote(AttemptID))
dbSendQuery(Connection,Query)

# Diconnect from Postgres        
dbDisconnect(Connection)        
