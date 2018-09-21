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

# Query available counties
Counties<-suppressWarnings(dbGetQuery(Connection,"SELECT arizona_place_id AS place_id, arizona_place_name AS place_name, geom FROM dicts.arizona_places WHERE placetype='county' AND within_arizona = 'TRUE';"))

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
                        selectInput("county","Choose a county",choices = Counties$place_name),
                        selectInput("map", "Choose a map:",choices = NCGMP09_titles$title),
                        selectInput("format","Choose a map format:",choices = c("GeoJSON","KML","ESRI Shapefile")),
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
queryMap<-function(collection_id) {
        Polygons<-paste0('SELECT "Label",geom FROM ncgmp09."MapUnitPolys" WHERE collection_id = ',sQuote(collection_id))
        MapUnitPolys = sf::st_read(Connection,query = Polygons)
        Description<-paste0('SELECT "Label","AreaFillRGB" AS color FROM ncgmp09."DescriptionOfMapUnits" WHERE collection_id = ',sQuote(collection_id))
        DescriptionOfMapUnits<-dbGetQuery(Connection,Description)
        MapUnitPolys<-merge(MapUnitPolys,DescriptionOfMapUnits,by="Label",all.x=TRUE)
        # Remove polys without color
        MapUnitPolys<-subset(MapUnitPolys,is.na(MapUnitPolys$color)!=TRUE)
        MapUnitPolys$color<-getColors(MapUnitPolys)
        return(MapUnitPolys)
        }

# Get the color vector from QueryMap
getColors<-function(QueryMap) {
        color<-sapply(QueryMap$color,strsplit,";")
        color<-sapply(color,function(x) rgb(as.numeric(x[1]),as.numeric(x[2]),as.numeric(x[3]),maxColorValue=255))
        return(color)
        }

# Plot the map
plotMap<-function(QueryMap) {
        mapview(QueryMap,col.regions=QueryMap$color)@map
        }

getAbstract<-function(collection_id) {
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

##################################### SERVER FUNCTIONS SCRIPT, CONVERSION ###################################
# Define server logic to plot map
server <- function(input, output) {
   collection_id<-reactive({
           NCGMP09_titles[which(NCGMP09_titles$title==input$map),"collection_id"]
           })
   
   output$abstract<-renderText({
           getAbstract(collection_id())
           })
   
   output$map_plot<-renderLeaflet({
           plotMap(queryMap(collection_id()))
           })
   
   file_format<-reactive({
           switch(input$format,
                "ESRI Shapefile" = "shp",
                "GeoJSON" = "geojson",
                "KML" = "kml")
                })
   
   output$downloadData<-downloadHandler(
           filename=function() {
                   paste(gsub(" ","",input$map),file_format(),sep=".")
           },
           content = function(file) {
                   sf::st_write(queryMap(collection_id()),file)
           })
   }

# Run the application 
shinyApp(ui = ui, server = server)