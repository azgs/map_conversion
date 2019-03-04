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

# Load or install shiny package
if (suppressWarnings(require("shinydashboard"))==FALSE) {
        install.packages("shinydashboard",repos="http://cran.cnr.berkeley.edu/");
        library("shinydashboard");
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

# Load or install shinyjs package
if (suppressWarnings(require("shinyjs"))==FALSE) {
        install.packages("shinyjs",repos="http://cran.cnr.berkeley.edu/");
        library("shinyjs");
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
Query<-paste0("SELECT collection_id, formal_name AS full_title, informal_name AS title
             FROM collections WHERE collection_id IN (SELECT DISTINCT collection_id FROM ncgmp09.",dQuote("MapUnitPolys"),");"
             )
            
# Query available ncgmp09 datasets
Titles<-suppressWarnings(dbGetQuery(Connection,Query))

#############################################################################################################
###################################### BUILD PAGE FUNCTIONS, CONVERSION #####################################
#############################################################################################################
# No functions at this time

######################################### BUILD PAGE SCRIPT, CONVERSION #####################################
# Define UI for application that draws a histogram
ui <- dashboardPage(
        # Application title
        dashboardHeader(
                title="Select Map"
                ),
        # Sidebar with a slider input for number of bins 
        dashboardSidebar(
                selectInput("map", "Choose a map:",choices=c("",Titles$title),selectize=TRUE),
                selectInput("format","Choose a map format:",choices = c("ESRI File Geodatabase","GeoJSON","KML","ESRI Shapefile")),
                downloadButton('downloadData', 'Download Data',class="butt"),
                tags$head(tags$style(".butt{background-color:white;} .butt{color: black;} .butt{margin-left: 15px;}")),
                tags$style(".skin-blue .sidebar a {color: #444}")
                ),
        dashboardBody(
                shinyjs::useShinyjs(),
                fluidRow(id="instructions_box",
                         shinydashboard::box(
                                 width=12,
                                 status="primary",
                                 title="Instructions",
                                 solidHeader=TRUE,
                                 includeHTML("www/instructions.html")
                                )
                        ),
                shinyjs::hidden(fluidRow(id="abstract_box",
                        shinydashboard::box(
                                width=12,
                                status="primary",
                                title=textOutput("title"),
                                solidHeader = TRUE,
                                textOutput("abstract")
                                )
                        )),
                shinyjs::hidden(fluidRow(id="metadata",
                        shinydashboard::box(
                                id="year_box",
                                width=2,
                                status="primary",
                                title="Year",
                                solidHeader = TRUE,
                                htmlOutput("year")
                                ),
                        shinydashboard::box(
                                id="author_box",
                                width=5,
                                status="primary",
                                title="Author(s)",
                                solidHeader = TRUE,
                                htmlOutput("authors")
                                ),
                        shinydashboard::box(
                                id="source_box",
                                width=5,
                                status="primary",
                                title="Source",
                                solidHeader = TRUE,
                                htmlOutput("url")
                                )
                        )),
                fluidRow(
                        # Show a plot of the generated distribution
                        leafletOutput("map_plot",height=600)
                        )
                )
        )

#############################################################################################################
######################################### SERVER FUNCTIONS, CONVERSION ######################################
#############################################################################################################
# Query the required map data and join it together
queryPolys<-function(collection_id) {
        Polygons<-paste0('SELECT * FROM ncgmp09."MapUnitPolys" WHERE collection_id = ',sQuote(collection_id))
        MapUnitPolys<-sf::st_read(Connection, query=Polygons)
        MapUnitPolys<-sf::st_transform(MapUnitPolys,4326) # hardcode in the wgs84
        Description<-paste0('SELECT * FROM ncgmp09."DescriptionOfMapUnits" WHERE collection_id = ',sQuote(collection_id))
        DescriptionOfMapUnits<-dbGetQuery(Connection,Description)
        MapUnitPolys<-merge(MapUnitPolys,DescriptionOfMapUnits,by="MapUnit",all.x=TRUE)
        # Remove polys without color
        MapUnitPolys<-subset(MapUnitPolys,is.na(MapUnitPolys$AreaFillRGB)!=TRUE)
        MapUnitPolys$OGR_STYLE<-getColors(MapUnitPolys)
        return(MapUnitPolys)
        }

# Merge the lines layers together
queryLines<-function(collection_id) {
        Lines<-paste0('SELECT * FROM ncgmp09."ContactsAndFaults" WHERE collection_id = ',sQuote(collection_id))
        ContactsAndFaults<-sf::st_read(Connection, query=Lines)
        if (sum(dim(ContactsAndFaults))==0) {return(NA)}
        ContactsAndFaults<-sf::st_transform(ContactsAndFaults,4326) # hardcode in the wgs84
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
        OrientationPoints<-sf::st_transform(OrientationPoints,4326) # hardcode in the wgs84
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
        mapview(QueryPolys[,c("FullName","Age","GeneralLithology","Description")],col.regions=QueryPolys$OGR_STYLE, map.types = "OpenStreetMap.DE",layer.name="layer")@map
        }

# A function to get and display the abstract
getAbstract<-function(collection_id) {
        # Construct the Query
        Query<-paste0(
                "SELECT char_string::text AS title
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
        sf::st_write(queryPolys(Input),paste0(Output,"/","MapUnitPolys",".",Format),delete_dsn=TRUE)
        Lines<-queryLines(Input)
        if (is.na(Lines)!=TRUE) {
                sf::st_write(Lines,paste0(Output,"/","ContactsAndFaults",".",Format),delete_dsn=TRUE)
                }
        Points<-queryPoints(Input)
        if (is.na(Points)!=TRUE) {
                sf::st_write(Points,paste0(Output,"/","OrientationPoints",".",Format),delete_dsn=TRUE)
                }
        return(Output)
        }
                      
# Write the results out to to the target folder, but force libkml
writeLIBKML<-function(Input,Output) {
        Polygons<-queryPolys(Input)
        # Style the polygons for KML
        Polygons$OGR_STYLE<-paste0("BRUSH(fc:",Polygons$OGR_STYLE,");(PEN(c:#000000,w:1px)")
        sf::st_write(Polygons,paste0(Output,"/MapUnitPolys.kml"),driver="libkml",delete_dsn=TRUE)
        Lines<-queryLines(Input)
        if (is.na(Lines)!=TRUE) {
                sf::st_write(Lines,paste0(Output,"/ContactsAndFaults.kml"),driver="libkml",delete_dsn=TRUE)
                }
        Points<-queryPoints(Input)
        if (is.na(Points)!=TRUE) {
                sf::st_write(Points,paste0(Output,"/OrientationPoints.kml"),driver="libkml",delete_dsn=TRUE)
                }
        return(Output)
        }

# Get the geodatabase
getGDB<-function(collection_id) {
        Output<-tempdir()
        Path<-dbGetQuery(Connection,paste0("SELECT azgs_path FROM collections WHERE collection_id = ",sQuote(collection_id)))
        # add .tar.gz IF .tar.gz is not in the path arleady
        # I do this because some versions of azlib collection table includs the zip extension and some do not.
        if (grepl(".tar.gz",Path)!=TRUE) {
                Path<-paste0(Path,".tar.gz")
                }
        # untar the results to the temp directory
        untar(Path,paste0(collection_id,"/gisdata/ncgmp09"),exdir=Output)
        return(Output)
        }

# Get the year
getYear<-function(collection_id) {
        Query<-paste0(
                "SELECT result::text 
                FROM (SELECT collection_id, json_data FROM metadata.metadata WHERE collection_id = ",sQuote(collection_id),") AS A,
                jsonb_array_elements(json_data #> '{gmd:MD_Metadata,gmd:identificationInfo}') identificationInfo,
                                     jsonb_array_elements(identificationInfo -> 'gmd:MD_DataIdentification') dataID,
                                     jsonb_array_elements(dataID -> 'gmd:citation') citation,
                                     jsonb_array_elements(citation ->  'gmd:CI_Citation') ci_citation,
                                     jsonb_array_elements(ci_citation -> 'gmd:date') date,
                                     jsonb_array_elements(date -> 'gmd:CI_Date') ci_date,
                                     jsonb_array_elements(ci_date -> 'gmd:date') date_2,
                                     jsonb_array_elements(date_2 -> 'gco:DateTime') result
                                     ;")
        Pubdate<-unlist(dbGetQuery(Connection,Query))
        Year<-substring(Pubdate,2,5) # hardcoded year extraction
        return(Year)
        }

# Get the authors
getAuthors<-function(collection_id) {
        Query<-paste0(
        "SELECT char_string::text 
        FROM (SELECT collection_id, json_data FROM metadata.metadata WHERE collection_id = ",sQuote(collection_id),") AS A,
        jsonb_array_elements(json_data #> '{gmd:MD_Metadata,gmd:identificationInfo}') identificationInfo,
                             jsonb_array_elements(identificationInfo -> 'gmd:MD_DataIdentification') dataID,
                             jsonb_array_elements(dataID -> 'gmd:citation') citation,
                             jsonb_array_elements(citation ->  'gmd:CI_Citation') ci_citation,
                             jsonb_array_elements(ci_citation -> 'gmd:citedResponsibleParty') party,
                             jsonb_array_elements(party -> 'gmd:CI_ResponsibleParty') responsible,
                             jsonb_array_elements(responsible -> 'gmd:individualName') individual,
                             jsonb_array_elements(individual -> 'gco:CharacterString') char_string
                             ;")
        Authors<-unlist(dbGetQuery(Connection,Query))
        Authors<-subset(Authors,Authors!='"Missing"')
        Authors<-gsub('"',"",Authors)
        if (length(Authors)>1) {
                Authors<-paste(Authors,collapse=";    ")
                }
        return(Authors)
        }

# Get the linkt o the current repository
getURL<-function(collection_id) {
        Query<-paste0(
                "SELECT char_string::text 
                FROM (SELECT collection_id, json_data FROM metadata.metadata WHERE collection_id = ",sQuote(collection_id),") AS A,
                jsonb_array_elements(json_data #> '{gmd:MD_Metadata,gmd:distributionInfo}') distribution_info,
                jsonb_array_elements(distribution_info -> 'gmd:MD_Distribution') distribution,
                jsonb_array_elements(distribution -> 'gmd:transferOptions') transfer,
                jsonb_array_elements(transfer ->  'gmd:MD_DigitalTransferOptions') digital,
                jsonb_array_elements(digital -> 'gmd:onLine') online,
                jsonb_array_elements(online -> 'gmd:CI_OnlineResource') online_resource,
                jsonb_array_elements(online_resource -> 'gmd:linkage') linkage,
                jsonb_array_elements(linkage -> 'gmd:URL') char_string
                ;")
        URL<-dbGetQuery(Connection,Query)
        return(URL)
        }

##################################### SERVER FUNCTIONS SCRIPT, CONVERSION ###################################
# Define server logic to plot map
server <- function(input, output,session) {
        collection_id<-reactive({
                Titles[which(Titles$title==input$map),"collection_id"]
                })
        
        output$year<-renderText({
                req(collection_id())
                paste("<b>",getYear(collection_id()),"</b>")
                })
        
        observeEvent(input$map,{
                if (length(collection_id())!=1) {
                        shinyjs::hide("metadata")
                        shinyjs::hide("abstract_box")
                        shinyjs::show("instructions_box")
                        }
                else {
                        shinyjs::show("metadata")
                        shinyjs::show("abstract_box")
                        shinyjs::hide("instructions_box")
                        }
                })
        
        output$title<-renderText({
                req(collection_id())
                Titles[which(Titles[,"collection_id"]==collection_id()),"full_title"]
                })
        
        output$authors<-renderText({
                req(collection_id())
                paste("<b>",getAuthors(collection_id()),"</b>")
                })
        
        output$abstract<-renderText({
                req(collection_id())
                getAbstract(collection_id())
                })

        output$url<-renderText({
                req(collection_id())
                paste("<a href=",getURL(collection_id()),">Arizona Geological Survey Repository</a>")
                })
   
        updateSelectizeInput(session,"map",choices=c("",Titles$title),server=TRUE)
        
        output$map_plot<-renderLeaflet({
                if (length(collection_id())!=1) {
                        mapview(st_sfc(st_point(c(-110.94287,32.22821)),crs=4326),map.types="OpenStreetMap.DE",layer.name="Arizona Geological Survey Building")@map
                        }
                else {plotMap(queryPolys(collection_id()))}
                })
        
        output$downloadData<-downloadHandler(
                filename=function() {
                        "output.zip"
                        },
                content = function(file) {
                        Output<-switch(input$format,
                                "ESRI File Geodatabase" = getGDB(collection_id()),
                                "GeoJSON" = writeLayers(collection_id(),tempdir(),"geojson"),
                                "KML" = writeLIBKML(collection_id(),tempdir()),
                                "ESRI Shapefile" = writeLayers(collection_id(),tempdir(),"shp")
                                )
                        zip(file,Output,flags = "-r -j -m")
                        },
                contentType = "application/zip"
                )
        }

# Run the application 
shinyApp(ui = ui, server = server)

# runApp(port=5448, host="0.0.0.0")
