# Methods and Functions are camelCase. Variables and Data Structures are PascalCase
# Fields generally follow snake_case for better SQL compatibility
# Dependency functions are not embedded in master functions
# []-notation is used wherever possible, and $-notation is avoided.
# []-notation is slower, but more explicit and works for atomic vectors

######################################### Load Required Libraries ###########################################
# Increase the timeout time and change the fancyquote settings
options(timeout=600, "useFancyQuotes"=FALSE)

# Load or install the rvest package
if (suppressWarnings(require("rvest"))==FALSE) {
        install.packages("rvest",repos="http://cran.cnr.berkeley.edu/");
        library("rvest");
        } 

# Load or install the xml package
if (suppressWarnings(require("XML"))==FALSE) {
        install.packages("XML",repos="http://cran.cnr.berkeley.edu/");
        library("XML");
        }                     

# Load or install the rcurl package
if (suppressWarnings(require("RCurl"))==FALSE) {
        install.packages("RCurl",repos="http://cran.cnr.berkeley.edu/");
        library("RCurl");
        }   

# Load or install the data.table package
# We use data.table::fread because it is more robust to the various encoding/quoting/delim issues of the complex text strings
# in the diamonds mysql database
if (suppressWarnings(require("data.table"))==FALSE) {
        install.packages("data.table",repos="http://cran.cnr.berkeley.edu/");
        library("data.table");
        }          

#############################################################################################################
##################################### SCRAPE THE WEB REPOSITORY, DIAMONDS ###################################
#############################################################################################################
# Because there are fewer nid folders than actual nid documents, I have decided to scrape the repository
# directly through web scraping

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

#################################### SCRAPE THE WEB REPOSITORY, DIAMONDS ####################################
# Download an initial list of all known nid values in the database
# all_nids<-read.csv("~/Desktop/Diamonds/all_nids.csv",stringsAsFactors=FALSE)
# colnames(all_nids)<-c("nid")

# Move to a new directory to hold the scraped repository
# setwd("~/Desktop/Diamonds/scraped_diamond")
# Move to a new directory to hold the scraped repository
Master<-"~/Desktop/Diamonds/scraped_diamond/19139Metadata"
setwd(Master)

# A set of logs
Empty<-vector() # Empty vector for flagging any collections without data
Blocked<-vector() # Empty vector for flagging any collectio that are blocked (i.e., invalid url)
Ghost<-vector() # Empty vector for flagging any collections that don't exist (i.e., no url)

# I wrote this as a script rather than as a function, I didn't want to functionalize it
# considering that so much is hard-coded
for (i in seq_along(Nids)) {
        print(Nids[i])
        # Make a directory
        Make<-paste0("mkdir ",Nids[i])
        system(Make)
        # Create the master URL
        MasterURL<-paste0("http://repository.azgs.az.gov/uri_gin/azgs/dlio/",Nids[i])
        # Check if the URL is valid
        if (check403(MasterURL)==TRUE) {Blocked=append(Blocked,Nids[i]); next;}
        if (check404(MasterURL)==TRUE) {Ghost=append(Ghost,Nids[i]); next;}        
        # Download the metadata from online and put it the metadata folder
        QueryXML<-paste0(MasterURL,"/iso19139.xml")
        Query<-paste0('cd ',Nids[i],' && mkdir metadata && curl -o "metadata/iso19139.xml" "',QueryXML,'"')
        system(Query)
        # Read the main page HTML into R
        HTML<-read_html(MasterURL)
        # extract the url's for each individual file
        FilePaths<-html_attr(html_nodes(HTML,".filefield-file >a"),"href")
        # Check if the data is empty
        if (length(FilePaths)==0) {Empty=append(Empty,Nids[i]); next;}
        # extract the file title name
        FileTitles<-html_attr(html_nodes(HTML,".filefield-file >a"),"title")
        for (j in 1:length(FilePaths)) {
                QueryFile<-paste0('cd ',Nids[i],' && curl -o "',FileTitles[[j]],'" "',FilePaths[[j]],'"')
                system(QueryFile)
                }
        # go into each nid folder move all pdf products into documents folder
        Query<-paste("cd",Nids[i],"&& mkdir documents && mv *.pdf documents")
        system(Query)
        # go into each nid folder move all image products into images folder
        Query<-paste("cd",Nids[i],"&& mkdir images && mv *.{png,jpg,gif} images")
        system(Query)
        # Should add a step here taht if the images folder is empty that it gets deleted
        }

# Write out the logs
write.csv(Empty,"Empty.csv")
write.csv(Blocked,"Blocked.csv")
write.csv(Ghost,"Ghost.csv")

#############################################################################################################
#################################### CONSTRUCT LIBRARY METADATA, DIAMOND ####################################
#############################################################################################################
# I apologize for making this a script rather tha a set of proper functions. There are too man "one-off"
# considerations here for it to be worth a robust, generic method.

#################################### CONSTRUCT LIBRARY METADATA, DIAMOND ####################################
# Move to a new directory to hold the scraped repository
Master<-"~/Desktop/Diamonds/scraped_diamond/19139Geodata"
File<-"iso19139.xml"
setwd(Master)

# Download an initial list of all known nid values in the database
#all_nids<-read.csv("~/Desktop/Diamonds/all_nids.csv",stringsAsFactors=FALSE)
# colnames(all_nids)<-c("nid")
# Now I use the nid folders that exist in the various reorganized directories in scraped diamond
Directories<-list.dirs(Master,recursive=FALSE,full.names=FALSE)
# Find only the numbered directories
Nids<-Directories[which(grepl("^[0-9]+$", Directories, perl = TRUE))]

# Master metadata table
FinalMatrix<-data.frame(matrix(NA,nrow=length(Nids),ncol=21))
colnames(FinalMatrix)<-c("original_url","language","citation","title","series","authors","pubdate","abstract","constraint","quality","lineage","north_latitude","south_latitude","west_longitude","east_longitude","collection","keywords","doc_files","image_files","note_files","gis_files")
rownames(FinalMatrix)<-Nids

# Breaks at i=1563 because of encoding error
for (i in seq_along(Nids)) {
        # Verify if the folder has XML
        nid_folder<-paste(Master,Nids[i],"metadata",File,sep="/")
        if (file.exists(nid_folder)!=TRUE) {print(c(Nids[i],"Does not have any XML metadata")); next;} 
        # Check if it is valid XML
        if (isXMLString(readChar(nid_folder,file.info(nid_folder)$size))!=TRUE) {print(c(Nids[i],"Does not have valid XML metadata")); next;}
        Metadata<-xmlToList(nid_folder)
        # Store the old_url
        FinalMatrix[i,"original_url"]<-paste0("http://repository.azgs.az.gov/uri_gin/azgs/dlio/",Nids[i])
        # Store the language
        Language<-Metadata$language$CharacterString
        if (is.null(Language)!=TRUE) {FinalMatrix[i,"language"]<-Language}
        # Store the citation
        FinalMatrix[i,"citation"]<-NA
        # Store the title
        Title<-Metadata$identificationInfo$MD_DataIdentification$citation$CI_Citation$title$CharacterString
        if (is.null(Title)!=TRUE) {FinalMatrix[i,"title"]<-Title}
         # Store the identifier - a.k.a., series
        Series<-Metadata$identificationInfo$MD_DataIdentification$citation$CI_Citation$identifier$MD_Identifier$code$CharacterString
        if (is.null(Series)!=TRUE) {FinalMatrix[i,"series"]<-Series}
        # Store the aturhots
        FinalMatrix[i,"authors"]<-NA
        # Store the publication date
        # Pubdate<-Metadata$identificationInfo$MD_DataIdentification$citation$CI_Citation$date$CI_Date$date$DateTime
        # if (is.null(Pubdate)!=TRUE) {FinalMatrix[i,"pubdate"]<-Pubdate}
        # We now do the pubdate outside of the loop because the 19115 metadata format does not track pubdate
        # Store the abstract
        Abstract<-Metadata$identificationInfo$MD_DataIdentification$abstract$CharacterString
        if (is.null(Abstract)!=TRUE) {FinalMatrix[i,"abstract"]<-Abstract}
         # Store the constraint
        FinalMatrix[i,"constraint"]<-NA
        # Store the quality
        Quality<-Metadata$dataQualityInfo$DQ_DataQuality$report$DQ_NonQuantitativeAttributeAccuracy$result$DQ_QuantitativeResult$value$Record
        if (is.null(Quality)!=TRUE) {FinalMatrix[i,"quality"]<-Quality}
        # Store to lineage
        Lineage<-Metadata$dataQualityInfo$DQ_DataQuality$lineage$LI_Lineage$statement$CharacterString
        if (is.null(Lineage)!=TRUE) {FinalMatrix[i,"lineage"]<-Lineage}
        # Store the north
        North<-Metadata$identificationInfo$MD_DataIdentification$extent$EX_Extent$geographicElement$EX_GeographicBoundingBox$northBoundLatitude$Decimal
        if (is.null(North)!=TRUE) {FinalMatrix[i,"north_latitude"]<-North}
        # Store the South
        South<-Metadata$identificationInfo$MD_DataIdentification$extent$EX_Extent$geographicElement$EX_GeographicBoundingBox$southBoundLatitude$Decimal
        if (is.null(South)!=TRUE) {FinalMatrix[i,"south_latitude"]<-South}
        # Store the East
        East<-Metadata$identificationInfo$MD_DataIdentification$extent$EX_Extent$geographicElement$EX_GeographicBoundingBox$eastBoundLongitude$Decimal
        if (is.null(East)!=TRUE) {FinalMatrix[i,"east_longitude"]<-East}
        # Store the West
        West<-Metadata$identificationInfo$MD_DataIdentification$extent$EX_Extent$geographicElement$EX_GeographicBoundingBox$westBoundLongitude$Decimal
        if (is.null(West)!=TRUE) {FinalMatrix[i,"west_longitude"]<-West}
        # Store the keywords
        FinalMatrix[i,"keywords"]<-NA
        # File Names
        FinalMatrix[i,"doc_files"]<-paste(list.files(paste0(Nids[i],"/documents")),collapse="|")
        # State whether there are images in the images folder
        if (length(list.files(paste(Master,Nids[i],"images",sep="/")))>0) {FinalMatrix[i,"image_files"]<-paste(list.files(paste0(Nids[i],"/images")),collapse="|")}
        else {unlink(paste0(Nids[i],"/images"),recursive=TRUE)}
        # State whether there are notes in the notes folder
        if (length(list.files(paste(Master,Nids[i],"notes",sep="/")))>0) {FinalMatrix[i,"note_files"]<-paste(list.files(paste0(Nids[i],"/notes"),recursive=TRUE,include.dirs=FALSE),collapse="|")}
        else {unlink(paste0(Nids[i],"/notes"),recursive=TRUE)}
        # State whether there are notes in the notes folder
        if (length(list.files(paste(Master,Nids[i],"gisdata",sep="/")))>0) {FinalMatrix[i,"gis_files"]<-paste(list.files(paste0(Nids[i],"/gisdata"),recursive=TRUE,include.dirs=FALSE),collapse="|")}
        else {unlink(paste0(Nids[i],"/gisdata"),recursive=TRUE)}
        # Print every 50 iterations
        if (i%%25==0) {print(i)}
        }

# The MySQL statement for the Authors.csv
# "SELECT DISTINCT nid, GROUP_CONCAT(DISTINCT field_core_originator_value SEPARATOR '|') AS authors FROM content_field_core_originator GROUP BY nid'""
Authors<-as.data.frame(data.table::fread("~/Desktop/Diamonds/authors.csv"),stringsAsFactors=FALSE)
# Subset the Authors table to only those nids in FinalMatrix
Authors<-subset(Authors,Authors[,"nid"]%in%rownames(FinalMatrix)==TRUE)
FinalMatrix[match(Authors[,"nid"],rownames(FinalMatrix)),"authors"]<-Authors[,"authors"]

# Get the keywords, which I exported from MySQL manually
KeywordKey<-as.data.frame(data.table::fread("~/Desktop/Diamonds/term_node.csv"),stringsAsFactors=FALSE)
KeywordDict<-as.data.frame(data.table::fread("~/Desktop/Diamonds/term_data.csv"),stringsAsFactors=FALSE)
KeywordKey[,"name"]<-KeywordDict[match(KeywordKey[,"tid"],KeywordDict[,"tid"]),"name"]
# Collapse all the terms by nid
NidKey<-tapply(KeywordKey[,"name"],KeywordKey[,"nid"],function(x) paste0(unique(x),collapse="|"))
# Subset the nidkey table to only those nids in FinalMatrix
NidKey<-subset(NidKey,names(NidKey)%in%rownames(FinalMatrix)==TRUE)
# Add the keywords to the FinalMatrix
FinalMatrix[match(names(NidKey),rownames(FinalMatrix)),"keywords"]<-NidKey

# Get the constraints which I export from MySQL manually as tsv
Constraint<-read.table("~/Desktop/Diamonds/constraint.tsv",stringsAsFactors=FALSE,header=TRUE)
Constraint<-by(Constraint,Constraint[,"nid"],function(x) x[which.max(x[,"vid"]),"field_core_res_constraint_value"])
Constraint<-setNames(as.vector(Constraint),names(Constraint))
# Subset the constraints table to only those nids in FinalMatrix
Constraint<-subset(Constraint,names(Constraint)%in%rownames(FinalMatrix)==TRUE)
FinalMatrix[match(names(Constraint),rownames(FinalMatrix)),"constraint"]<-Constraint

# Download the citation (content_field_core_res_access) information, which I export from MySQL manually as tsv
Citation<-read.table("~/Desktop/Diamonds/citation.tsv",header=TRUE,stringsAsFactors=FALSE)
Citation<-by(Citation,Citation[,"nid"],function(x) x[which.max(x[,"vid"]),"field_core_res_access_value"])
Citation<-setNames(as.vector(Citation),names(Citation))
# Subset the constraints table to only those nids in FinalMatrix
Citation<-subset(Citation,names(Citation)%in%rownames(FinalMatrix)==TRUE)
FinalMatrix[match(names(Citation),rownames(FinalMatrix)),"citation"]<-Citation

# Download the collections information, taken from lupe thorugh Drupal
Collections<-read.csv("~/Desktop/Diamonds/collections.csv",stringsAsFactors=FALSE)
# Subset to only nids in the final matrix
Collections<-subset(Collections,Collections[,"nid"]%in%rownames(FinalMatrix)==TRUE)
# Input the collection into the final matrix
FinalMatrix[match(Collections[,"nid"],rownames(FinalMatrix)),"collection"]<-Collections[,"collection"]

# Download the pubdate infromaton, which i export from MySQL manually as tsv
Pubdate<-read.table("/Users/zaffos/Desktop/Diamonds/pubdate.tsv",header=TRUE,stringsAsFactors=FALSE)
Pubdate<-by(Pubdate,Pubdate[,"nid"],function(x) x[which.max(x[,"vid"]),"field_core_pub_date_value"])
Pubdate<-setNames(as.vector(Pubdate),names(Pubdate))
# Subset the constraints table to only those nids in FinalMatrix
Pubdate<-subset(Pubdate,names(Pubdate)%in%rownames(FinalMatrix)==TRUE)
FinalMatrix[match(names(Pubdate),rownames(FinalMatrix)),"pubdate"]<-Pubdate

# Clean up the \n
FinalMatrix[,"abstract"]<-gsub("\\n"," ",FinalMatrix[,"abstract"])

# Remove the misc/ from note_files and legacy/, raster/, and ncgmp09/ from gis_files
FinalMatrix[,"note_files"]<-gsub("misc/","",FinalMatrix[,"note_files"])
FinalMatrix[,"gis_files"]<-gsub("legacy/","",FinalMatrix[,"gis_files"])
FinalMatrix[,"gis_files"]<-gsub("ncgmp09/","",FinalMatrix[,"gis_files"])
FinalMatrix[,"gis_files"]<-gsub("raster/","",FinalMatrix[,"gis_files"])

write.csv(FinalMatrix,"library_metadata.csv")

#############################################################################################################
###################################### RENAME GEODATA FOLDERS, DIAMOND ######################################
#############################################################################################################
# We changed the spec from geodata to gisdata. This brief script changes all geodata folders to gisdata

###################################### RENAME GEODATA FOLDERS, DIAMOND ######################################
# Move to a new directory to hold the scraped repository
Master<-"~/Desktop/Diamonds/scraped_diamond/19139Geodata"
setwd(Master)

# Download an initial list of all known nid values in the database
#all_nids<-read.csv("~/Desktop/Diamonds/all_nids.csv",stringsAsFactors=FALSE)
# colnames(all_nids)<-c("nid")
# Now I use the nid folders that exist in the various reorganized directories in scraped diamond
Directories<-list.dirs(Master,recursive=FALSE,full.names=FALSE)
# Find only the numbered directories
Nids<-Directories[which(grepl("^[0-9]+$", Directories, perl = T))]

for (i in seq_along(Nids)) {
        Old<-paste(Master,Nids[i],"geodata",sep="/")
        New<-paste(Master,Nids[i],"gisdata",sep="/")
        Query<-paste("mv",Old,New)
        system(Query)
        }

#############################################################################################################
####################################### RENAME EMAIL METADATA, DIAMOND ######################################
#############################################################################################################
# This script updates the email and contact information for all of the repository metadata
# I do this by calling down to system and using the regex `sed` rather than R's `gsub( )`. 
# That's definitely bad practice, but I don't want to load the xml into R. I'd have to be insane and hate myself.

# Technically this could/should be part of the earlier script, but fuck it at this point

# The general sed formula is as follows, where -i means to keep and save to original file.
# sed -i 's/original_term/replacement_term/g' ISO19139.xml
# Mac OSx has a non-standard sed implementation that requires you to put an empty char string
# sed -i "" 's/original_term/replacement_term/g' ISO19139.xml
# This makes life a bitch because you have to use sQuote( ) bullshit. 
# I have hate in my heart

# Replace term in file using `sed` through system
autoSED<-function(Original,Replacement,File="iso19139.xml") {
        for (term in Original) {
                InternalCMD<-sQuote(paste0("s/",term,"/",Replacement,"/g")) # assumes useFancyQuotes=FALSE
                FullQuery<-paste("sed -i",'""',InternalCMD,File)
                system(FullQuery)
                }
        }

####################################### RENAME METADATA EMAIL, DIAMOND ######################################
# Move to a new directory to hold the scraped repository
Master<-"~/Desktop/Diamonds/scraped_diamond/19139Metadata"
setwd(Master)
# Specify expected metadata format
File<-"iso19139.xml"

# use the nid folders that exist in the various reorganized directories (i.e., Master) in scraped diamond
Directories<-list.dirs(Master,recursive=FALSE,full.names=FALSE)
# Find only the numbered directories
Nids<-Directories[which(grepl("^[0-9]+$", Directories, perl = TRUE))]


# Replace emails, I get a list of acceptable emails by going to the original drupal MYSQL database
# And doing SELECT DISTINCT `field_cont_res_email_email` FROM `content_field_cont_res_email` and equivalent cmd for `content_field_cont_cit_email`
# Ideally I would use DBI to connect and do this entirely in R, but I have really gotten around to using MySQL in R
Emails<-c("michael.conway@azgs.az.gov","michael.conway@azga.az.gov","micheal.conway@azgs.az.gov","Steve.Rauzzi@azgs.az.gov","helen.ireland@azgs.az.gov","inquiries@azgs.az.gov","fmconway@email.arizona.edu","store@azgs.az.gov","Casey.Brown@azgs.az.gov","richard.holm@nau.edu","mcocker@usgs.gov","DavidFBriggs@aol.com","justin.davis@dnr.mo.gov","kmurray@azland.gov")
NewEmail<-"azgs-info@email.arizona.edu"
for (i in seq_along(Nids)) {
        # Create path to the xml
        XML<-paste(Master,Nids[i],"metadata",File,sep="/")
        autoSED(Emails,NewEmail,XML)
        # Print every 25 iterations
        if (i%%25==0) {print(i)}
        }

# In principle, this procedure could be used to update all of the metadata, but I've decided that a more proper XML solution is probably safer.

#############################################################################################################
####################################### ZIP GEODATABASES AND SHP, DIAMOND ###################################
#############################################################################################################


#################################### CONSTRUCT LIBRARY METADATA, DIAMOND ####################################
# Move to a new directory to hold the scraped repository
Master<-"~/Desktop/Diamonds/scraped_diamond/test/19115Geodata"
File<-"iso19139.xml"
setwd(Master)

# Now I use the nid folders that exist in the various reorganized directories in scraped diamond
Directories<-list.dirs(Master,recursive=FALSE,full.names=FALSE)
# Find only the numbered directories
Nids<-Directories[which(grepl("^[0-9]+$", Directories, perl = TRUE))]

for (i in seq_along(Nids)) {
        Path<-paste(Master,Nids[i],"gisdata",sep="/")
        # Check for a geodatabase
        if (any(grepl(".gdb",list.dirs(Path)))) {
                Geodatabase<-list.dirs(Path,)[grep(".gdb",list.dirs(Path))]
                Query<-paste("zip -rm",paste0(Geodatabase,".zip"),Geodatabase)
                system(Query)
                }
        if (any(grepl(".shp",list.dirs(Path)))) {
                Shapefiles<-list.dirs(Path,)[grep(".shp",list.dirs(Path))]
                for (i in seq_along(Shapefiles)) {
                        Query<-paste("zip -rm",paste0(Shapefiles[i],".zip"),Shapefiles[i]) 
                        system(Query)
                        }
                }
        }
