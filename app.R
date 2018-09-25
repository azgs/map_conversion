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

# Load or install sf package
if (suppressWarnings(require("sf"))==FALSE) {
        install.packages("sf",repos="http://cran.cnr.berkeley.edu/");
        library("sf");
        }

# Load or install shiny package
if (suppressWarnings(require("shiny"))==FALSE) {
        install.packages("shiny",repos="http://cran.cnr.berkeley.edu/");
        library("shiny");
        } 

# Load or install RPostgreSQL package
if (suppressWarnings(require("RPostgreSQL"))==FALSE) {
        install.packages("RPostgreSQL",repos="http://cran.cnr.berkeley.edu/");
        library("RPostgreSQL");
        } 

# Load or install leaflet package
if (suppressWarnings(require("leaflet"))==FALSE) {
        install.packages("leaflet",repos="http://cran.cnr.berkeley.edu/");
        library("leaflet");
        }

# Load or install mapview package
if (suppressWarnings(require("mapview"))==FALSE) {
        install.packages("mapview",repos="http://cran.cnr.berkeley.edu/");
        library("mapview");
        }

#############################################################################################################
####################################### LOAD DATA FUNCTIONS, CONVERSION #####################################
#############################################################################################################
# No functions at this time

######################################### LOAD DATA SCRIPT, CONVERSION ######################################
# Download the config file
Credentials<-as.matrix(read.table("./credentials/Credentials.yml",row.names=1))
# Connect to PostgreSQL
Driver <- dbDriver("PostgreSQL") # Establish database driver
Connection <- dbConnect(Driver, dbname = Credentials["database:",], host = Credentials["host:",], port = Credentials["port:",], user = Credentials["user:",], password = Credentials["password:",])

# Construct the Query
Query<-paste0(
             "SELECT collection_id, char_string AS title
             FROM (SELECT collection_id, json_data FROM metadata.metadata WHERE collection_id IN 
             (SELECT DISTINCT collection_id FROM ncgmp09.",
             dQuote("MapUnitPolys"),
             ")) AS A,
             jsonb_array_elements(json_data #> '{gmd:MD_Metadata,gmd:identificationInfo}') identificationInfo,
             jsonb_array_elements(identificationInfo -> 'gmd:MD_DataIdentification') dataID,
             jsonb_array_elements(dataID -> 'gmd:citation') citation,
             jsonb_array_elements(citation ->  'gmd:CI_Citation') ci_citation,
             jsonb_array_elements(ci_citation -> 'gmd:title') title,
             jsonb_array_elements(title -> 'gco:CharacterString') char_string
             ;")

# Query available ncgmp09 datasets
NCGMP09_titles<-suppressWarnings(dbGetQuery(Connection,Query))

#############################################################################################################
###################################### BUILD PAGE FUNCTIONS, CONVERSION #####################################
#############################################################################################################
# No functions at this time

######################################### BUILD PAGE SCRIPT, CONVERSION #####################################
# Define UI for application that draws a histogram
ui <- fluidPage(
        # Application title
        titlePanel("Arizona Geological Survey, Map Conversion Tool"),
        # Sidebar with a slider input for number of bins 
        sidebarLayout(
                sidebarPanel(
                        selectInput("map", "Choose a map:",choices=c("",NCGMP09_titles$title),selectize=TRUE),
                        selectInput("format","Choose a map format:",choices = c("OpenFileGDB","GeoJSON","KML","ESRI Shapefile")),
                        # Button
                        downloadButton("downloadData", "Download")
                        ),
                mainPanel(
                        textOutput("abstract")
                        ),
                ),
        # Show a plot of the generated distribution
        leafletOutput("map_plot")
        )

#############################################################################################################
######################################### SERVER FUNCTIONS, CONVERSION ######################################
#############################################################################################################
# Query the required map data and join it together
queryPolys<-function(collection_id) {
        Polygons<-paste0('SELECT * FROM ncgmp09."MapUnitPolys" WHERE collection_id = ',sQuote(collection_id))
        MapUnitPolys<-sf::st_read(Connection, query=Polygons)
        Description<-paste0('SELECT * FROM ncgmp09."DescriptionOfMapUnits" WHERE collection_id = ',sQuote(collection_id))
        DescriptionOfMapUnits<-dbGetQuery(Connection,Description)
        MapUnitPolys<-merge(MapUnitPolys,DescriptionOfMapUnits,by="Label",all.x=TRUE)
        # Remove polys without color
        MapUnitPolys<-subset(MapUnitPolys,is.na(MapUnitPolys$AreaFillRGB)!=TRUE)
        MapUnitPolys$AreaFillRGB<-getColors(MapUnitPolys)
        return(MapUnitPolys)
        }

# Merge the lines layers together
queryLines<-function(collection_id) {
        Lines<-paste0('SELECT * FROM ncgmp09."ContactsAndFaults" WHERE collection_id = ',sQuote(collection_id))
        ContactsAndFaults<-sf::st_read(Connection, query=Lines)
        if (sum(dim(ContactsAndFaults))==0) {return(NA)}
        Glossary<-paste0('SELECT * FROM ncgmp09."Glossary" WHERE collection_id = ',sQuote(collection_id)) 
        Glossary<-dbGetQuery(Connection,Glossary)
        if (sum(dim(Glossary))==0) {return(NA)}
        # Do a left join of ContactsAndFaults with MapUnits
        ContactsAndFaults<-merge(ContactsAndFaults,Glossary,by.x="Type",by.y="Term",all.x=TRUE)
        return(ContactsAndFaults)
        }

# Merge the points layers together
queryPoints<-function(collection_id) {
        Points<-paste0('SELECT * FROM ncgmp09."ContactsAndFaults" WHERE collection_id = ',sQuote(collection_id))
        OrientationPoints<-sf::st_read(Connection, query=Points)
        if (sum(dim(Points))==0) {return(NA)}
        Glossary<-paste0('SELECT * FROM ncgmp09."Glossary" WHERE collection_id = ',sQuote(collection_id)) 
        Glossary<-dbGetQuery(Connection,Glossary)
        if (sum(dim(Glossary))==0) {return(NA)}
        # Do a left join of ContactsAndFaults with MapUnits
        OrientationPoints<-merge(OrientationPoints,Glossary,by.x="Type",by.y="Term",all.x=TRUE)
        return(OrientationPoints)
        }

# Get the color vector from QueryPolys
getColors<-function(QueryPolys) {
        color<-sapply(QueryPolys$AreaFillRGB,strsplit,";")
        color<-sapply(color,function(x) rgb(as.numeric(x[1]),as.numeric(x[2]),as.numeric(x[3]),maxColorValue=255))
        return(color)
        }

# Plot the map
plotMap<-function(QueryPolys) {
        mapview(QueryPolys[,c("FullName","Age","GeneralLithology","Description")],col.regions=QueryPolys$AreaFillRGB, map.types = "OpenStreetMap.DE",layer.name="layer")@map
        }

# A function to get and display the abstract
getAbstract<-function(collection_id) {
        if (length(collection_id)!=1) {return("Please select an Arizona Geological Survey map for download.")}
        # Construct the Query
        Query<-paste0(
                "SELECT char_string AS title
                FROM (SELECT collection_id, json_data FROM metadata.metadata WHERE collection_id = '",collection_id,"') AS A,
                jsonb_array_elements(json_data #> '{gmd:MD_Metadata,gmd:identificationInfo}') identificationInfo,
                jsonb_array_elements(identificationInfo -> 'gmd:MD_DataIdentification') dataID,
                jsonb_array_elements(dataID -> 'gmd:abstract') abstract,
                jsonb_array_elements(abstract ->  'gco:CharacterString') char_string
                ;")
        # Query abstract
        Abstract<-suppressWarnings(dbGetQuery(Connection,Query))
        return(unlist(Abstract))
        }

# Write the results out to to the target folder
writeLayers<-function(Input,Output,Format) {
        sf::st_write(queryPolys(Input),paste(Output,"MapUnitPolys",sep="/"),delete_dsn=TRUE,driver=Format)
        Lines<-queryLines(Input)
        if (is.na(Lines)!=TRUE) {
                sf::st_write(Lines,paste(Output,"ContactsAndFaults",sep="/"),delete_dsn=TRUE,driver=Format)
                }
        Points<-queryPoints(Input)
        if (is.na(Points)!=TRUE) {
                sf::st_write(Points,paste(Output,"OrientationPoints",sep="/"),delete_dsn=TRUE,driver=Format)
                }
        return(Output)
        }

# Get the geodatabase
getGDB<-function(collection_id) {
        Path<-dbGetQuery(Connection,paste0("SELECT azgs_path FROM collections WHERE collection_id = ",sQuote(collection_id)))
        return(paste(Path,"gisdata","ncgmp09",sep="/"))
        }

##################################### SERVER FUNCTIONS SCRIPT, CONVERSION ###################################
# Define server logic to plot map
server <- function(input, output,session) {
        collection_id<-reactive({
                NCGMP09_titles[which(NCGMP09_titles$title==input$map),"collection_id"]
                })
   
        output$abstract<-renderText({
                getAbstract(collection_id())
                })
   
        updateSelectizeInput(session,"map",choices=c("",NCGMP09_titles$title),server=TRUE)
        
        output$map_plot<-renderLeaflet({
                if (length(collection_id())!=1) {
                        mapview(st_sfc(st_point(c(-110.94287,32.22821)),crs=4326))@map
                        }
                else {plotMap(queryPolys(collection_id()))}
                })
   
   output$downloadData<-downloadHandler(
           filename=function() {
                "output.zip"
                },
           content = function(file) {
                Output<-switch(input$format,
                        "OpenFileGDB" = getGDB(collection_id()),
                        "GeoJSON" = writeLayers(collection_id(),tempdir(),"GeoJSON"),
                        "KML" = writeLayers(collection_id(),tempdir(),"KML"),
                        "ESRI Shapefile" = writeLayers(collection_id(),tempdir(),"ESRI Shapefile")
                        )
                zip(file,Output,flags = "-r -j -m")
                },
           contentType = "application/zip"
           )
   }

# Run the application 
shinyApp(ui = ui, server = server)