
# Custom functions are camelCase. Arrays and Arguments are PascalCase
# Dependency functions are not embedded in master functions
# []-notation is used wherever possible, and $-notation is avoided.

######################################### Load Required Libraries ###########################################
# Load or install sf
if (suppressWarnings(require("sf"))==FALSE) {
        install.packages("sf",repos="http://cran.cnr.berkeley.edu/");
        library("sf");
        }

######################################### Load The Command Arguments ########################################
# Load the command line arguments
CommandArguments = commandArgs(TRUE)
# Check if the appropriate number of arguments was submitted
if (length(CommandArguments)!=4) {
	stop("Must specify target postgres schema, postgres table, destination, and desired format")
	}

########################################### Read and Write the File #########################################
# Read the table into R
Table = sf::st_read("PG:dbname=preservation",c(CommandArguments[1],CommandArguments[2]))

# Write the table back out in the desired format
sf::st_write(Table,CommandArguments[3],driver=CommandArguments[4])
