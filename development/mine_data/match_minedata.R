# Methods and Functions are camelCase. Variables and Data Structures are PascalCase
# Fields generally follow snake_case for better SQL compatibility
# Dependency functions are not embedded in master functions
# []-notation is used wherever possible, and $-notation is avoided.
# []-notation is slower, but more explicit and works for atomic vectors

######################################### Load Required Libraries ###########################################
# Increase the timeout time and change the fancyquote settings
options(timeout=600, "useFancyQuotes"=FALSE)

# Load or install the rcurl package
if (suppressWarnings(require("RCurl"))==FALSE) {
        install.packages("RCurl",repos="http://cran.cnr.berkeley.edu/");
        library("RCurl");
        }   

# Load or install the jsonlite package
if (suppressWarnings(require("jsonlite"))==FALSE) {
        install.packages("jsonlite",repos="http://cran.cnr.berkeley.edu/");
        library("jsonlite");
        }

#############################################################################################################
##################################### SCRAPE THE WEB REPOSITORY, MINEDATA ###################################
#############################################################################################################
# Check for valid URL
# From stack overflow https://stackoverflow.com/questions/14820286/get-response-header
check403<-function(URL) {
        h<-basicHeaderGatherer()
        doc<-getURI(URL,headerfunction=h$update)
        return(h$value()[["status"]]=="403")
        }

check404<-function(URL) {
        h<-basicHeaderGatherer()
        doc<-getURI(URL,headerfunction=h$update)
        return(h$value()[["status"]]=="404")
        }

# Function for building the keywoords matrix
# dep of fillForm()
parseKeywords<-function(Entry) {
        # I would prefer to do this in a more elegant way to check for 0-length, but who cares really?
        Theme<-unlist(strsplit(Entry$keywords_theme,","))
        if (length(Theme)>0) {
                Theme<-cbind(Theme,"theme")
                }
        else {
                Theme<-cbind(NA,"theme")
                }
        Places<-unlist(strsplit(Entry$keywords_place,","))
        if (length(Places)>0) {
                Places<-cbind(Places,"place")
                }
        else {
                Places<-cbind(NA,"place")
                }
        Times<-unlist(strsplit(Entry$keywords_time,","))
        if (length(Times)>0) {
                Times<-cbind(Times,"time")    
                }
        else {
                Times<-cbind(NA,"time")
                }
        Frame<-as.data.frame(rbind(Theme,Places,Times))
        colnames(Frame)<-c("name","type")
        Frame<-na.omit(Frame)
        return(Frame)
        }

# Fill out the template with the information from the CSV
fillForm<-function(Entry,Template) {
        Template$title<-Entry$title
        Template$authors$person<-Entry$authors
        Template$collection_group$name<-"Arizona Department of Mines and Mineral Resources"
        Template$collection_group$id<-22
        Template$year<-Entry$year
        Template$series<-Entry$collection_group
        Template$abstract<-Entry$abstract
        Template$links[1,"url"]<-Entry$links
        Template$bounding_box$north<-strsplit(Entry$coordinates,",")[[1]][1]
        Template$bounding_box$south<-strsplit(Entry$coordinates,",")[[1]][1]
        Template$bounding_box$east<-strsplit(Entry$coordinates,",")[[1]][2]
        Template$bounding_box$west<-strsplit(Entry$coordinates,",")[[1]][2]
        Template$keywords<-parseKeywords(Entry)
        return(Template)
        }

# The macro for downloading
scrapeMacro<-function(Drupal,Template) {
        # A set of logs
        Blocked<-vector() # Empty vector for flagging any collectio that are blocked (i.e., invalid url)
        Ghost<-vector() # Empty vector for flagging any collections that don't exist (i.e., no url)
        for (i in 1:nrow(Drupal)) {
                print(i)
                # Check if the URL is valid
                if (check403(Drupal[i,"links"])==TRUE) {Blocked=append(Blocked,i); next;}
                if (check404(Drupal[i,"links"])==TRUE) {Ghost=append(Ghost,i); next;}  
                # Fill out the form
                Metadata<-fillForm(Drupal[i,],Template)  
                # Make the directory
                system(paste0("mkdir ",i))
                # Write the template
                write(toJSON(Metadata,pretty=TRUE,na="null",null="null",auto_unbox=TRUE),paste0(i,"/azgs.json"))
                # curl the files, and let god sort them out later
                Files<-unlist(strsplit(as.character(Drupal[i,"files"]),","))
                for (file in Files) {                         
                        # Remove spaces...
                        file<-gsub('[[:space:]]',"",file)
                        QueryFile<-paste0('cd ',i,' && curl -o "',tail(unlist(strsplit(file,"/")),1),'" "',file,'"')
                        system(QueryFile)
                        }
                # go into each folder move all pdf products into documents folder
                Query<-paste("cd",i,"&& mkdir documents && mv *.pdf documents")
                system(Query)
                # go into each nid folder move all image products into images folder
                # Query<-paste("cd",i,"&& mkdir images && mv *.{png,jpg,gif} images")
                # system(Query)
                }
        }    

#################################### SCRAPE THE WEB REPOSITORY, MINEDATA ####################################
# Set the working directory, won't be needed (or desirable) if run from cmd line
setwd("~/Desktop/mine_data")

# Load in the original template file for the metadata schema
Template<-jsonlite::fromJSON("config.json")
# Load in the minedata report taken from Drupal
Drupal<-read.table("minedata.txt",sep="|",stringsAsFactors=FALSE,header=TRUE)

# Clean up the metadata export file
Drupal[which(Drupal[,"authors"]==""),"authors"]<-NA
Drupal[which(Drupal[,"year"]==""),"year"]<-NA

# Let's run this macro
scrapeMacro(Drupal,Template)

# Let's check for images or anything that isn't a pdf doc
# AllFiles<-list.files(getwd(),recursive=TRUE)
# Ignore the JSON Files
# Other<-AllFiles[-c(grep("azgs.json",AllFiles),grep(".pdf",AllFiles))]

