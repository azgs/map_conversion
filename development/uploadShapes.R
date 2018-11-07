# Custom functions are camelCase. Arrays and Arguments are PascalCase

######################################### Load The Command Arguments ########################################
# Load the command line arguments
CommandArguments = commandArgs(TRUE)
# Check if the appropriate number of arguments was submitted
if (length(CommandArguments)!=2) {
	stop("Must specify target folder and target postgres schema")
	}
        
#############################################################################################################
############################################### shp2pgsql, FUNCTION #########################################
#############################################################################################################
# This calls down to system for shp2pgsql
autoPGSQL<-function(Database="preservation",Target=CommandArguments[1],Schema=CommandArguments[2]) {
	  # Find all the shapefiles in the folder
          Shapefiles<-list.files(Target,pattern=".shp$")
          # Strip .shp from the end of the filenames for the postgres tables
          TableNames<-substr(Shapefiles, 1, nchar(Shapefiles)-4)
          # Loop through and upload each to postgres
          for (i in seq_len(length(Shapefiles))) {
                    TableName<-paste(Schema,TableNames[i],sep=".")
		    Command<-paste("shp2pgsql -I -k -s 4326",Shapefiles[i],TableName,"| psql",Database,sep=" ")
		    FinalCommand<-paste("cd",Target,"&&",Command,sep=" ")
		    system(FinalCommand)
		    }
	  }
        
############################################### shp2pgsql, SCRIPT ###########################################
# Write all shapefiles to postgres
autoPGSQL("preservation",CommandArguments[1],Schema=CommandArguments[2])
