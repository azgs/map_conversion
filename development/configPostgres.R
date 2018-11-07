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
CommandArguments <- commandArgs(TRUE)
# Check if the appropriate number of arguments was submitted
if (length(CommandArguments)!=1) {
	stop("Must specify path target postgres database.")
	}

# Create the database, this ensure you no longer need to check for duplication
Creation<-paste("createdb",CommandArguments[1])
system(Creation)

# Link to the postgres database
Connection <- dbConnect(PostgreSQL(), dbname = CommandArguments[1]) 

# Create the postgis extension
dbSendQuery(Connection,"CREATE EXTENSION postgis;")

#############################################################################################################
############################################## PUBLIC SCRIPT ################################################
#############################################################################################################
# Create the project_definitions table. This table is for defining the overarching funding/project that
# A set of data collections were collected under - e.g, StateMap 2017, NGGDP 2018. 
# All collections must be associated with a project.
# For older collections belonging to an unknown project, use "unknown legacy project"
dbSendQuery(Connection,"CREATE TABLE project_defs (
        project_id serial PRIMARY KEY,
        project_name text NOT NULL,
        project_desc text NOT NULL
        );")

# Create the publication_defs table. This table is for defining the publication
# associated with a set of data. Not all data will have been published - e.g., journal, book, field guide.
dbSendQuery(Connection,"CREATE TABLE publication_defs (
        publication_id serial PRIMARY KEY,
        publication_name text NOT NULL,
        publication_outlet text[] NOT NULL,
	publication_volume integer,
	publication_issue integer,
        first_author text NOT NULL,
	all_authors text[] NOT NULL,
        year smallint NOT NULL,
        bibjson json, --json of publication metadata
        mapjson json --json of map metadata
        );")

# This is the master_table, its purpose to to keep track of what collections have been entered and their relations
dbSendQuery(Connection,"CREATE TABLE master_table (
        collection_id serial PRIMARY KEY, 
        project_id integer NOT NULL REFERENCES project_defs(project_id),
        publication_id integer UNIQUE REFERENCES publication_defs(publication_id), -- Unique because collection_id is synonymous with publication_id, but not all collections may have publication_id
        formal_name text UNIQUE,
        informal_name text,
        azgs_path text NOT NULL UNIQUE,
        azlib_path text,
        usgs_path text,
	doi text
        );")
# Add a comment describing the date and time that the database was created
dbSendQuery(Connection,paste0("COMMENT ON TABLE master_table IS ",sQuote(Sys.time())))

# This is the upload_log table, its purpose is to help keep track of what uploads have been attempted and whether
# They were successful, and whether they were removed if unsuccessfull
dbSendQuery(Connection,"CREATE TABLE upload_log (
        attempt_id serial PRIMARY KEY,
        collection_id integer NOT NULL REFERENCES master_table(collection_id),
        upload_time timestamptz NOT NULL,
        success boolean NOT NULL,
        removed boolean NOT NULL
        );")

#############################################################################################################
############################################### DOCUMENTS SCHEMA ############################################
#############################################################################################################
# Create the documents schema 
dbSendQuery(Connection,"CREATE SCHEMA documents;")

# Create a type of acceptable images
dbSendQuery(Connection,"CREATE TYPE doc_type AS ENUM('report','journal','chapter','book','guide','misc','abstract');")

# This is the master_table for the documents schema that details the location of documents and what they are associated with
dbSendQuery(Connection,"CREATE TABLE documents.doc_defs (
        doc_id serial PRIMARY KEY,
        collection_id integer REFERENCES master_table(collection_id),
        doc_type doc_type,
        azgs_path text NOT NULL UNIQUE,
        doc_doi text,
        restricted boolean NOT NULL, -- Copyrighted, redacted, etc.
        geom geometry
        );")

#############################################################################################################
############################################### IMAGES SCHEMA ###############################################
#############################################################################################################
# Create the images schema
dbSendQuery(Connection,"CREATE SCHEMA images;")

# Create a type of acceptable images
dbSendQuery(Connection,"CREATE TYPE image_type AS ENUM('photo','raster','pdf','other');")

# This is the master_table for the images schema that details the location of images and what they are associated with
dbSendQuery(Connection,"CREATE TABLE images.image_defs (
        image_id serial PRIMARY KEY,
        collection_id integer REFERENCES master_table(collection_id),
        image_type image_type,
        azgs_path text NOT NULL UNIQUE,
        caption text NOT NULL,
        restricted boolean NOT NULL, -- Copyrighted, redacted, etc.
        geom geometry
        );")

# Raster maps and images, I've decided to handle this separately from the intial configuration.
dbSendQuery(Connection,"CREATE TABLE images.rasters (
	rid serial PRIMARY KEY,
	image_id integer REFERENCES images.image_defs(image_id),
	rast raster
	);")
# Create a gist index on the rasters
dbSendQuery(Connection,"CREATE INDEX ON images.rasters USING GiST (ST_ConvexHull(rast));")

#############################################################################################################
############################################### dict(IONARY) SCHEMA #########################################
#############################################################################################################
# Create the dictionary schema
dbSendQuery(Connection,"CREATE SCHEMA dicts;")

# Download the minerals dictsionary
Minerals<-read.csv("https://macrostrat.org/api/v2/defs/minerals?all&format=csv",stringsAsFactors=FALSE)
# Write the dictionary to postgres
dbWriteTable(Connection,c("dicts","minerals"),value=Minerals,row.names=FALSE)
# Specify the primary key
dbSendQuery(Connection,'ALTER TABLE dicts.minerals ADD PRIMARY KEY ("mineral_id");')

# Download the lithologies dictsionary
Lithologies<-read.csv("https://macrostrat.org/api/V2/defs/lithologies?all&format=csv",stringsAsFactors=FALSE)
# Write the dictionary to postgres
dbWriteTable(Connection,c("dicts","lithologies"),value=Lithologies,row.names=FALSE)
# Specify the primary key
dbSendQuery(Connection,'ALTER TABLE dicts.lithologies ADD PRIMARY KEY ("lith_id");')

# Download the intervals dictsionary
Intervals<-read.csv("https://macrostrat.org/api/V2/defs/intervals?all&format=csv",stringsAsFactors=FALSE)
# Write the dictionary to postgres
dbWriteTable(Connection,c("dicts","intervals"),value=Intervals,row.names=FALSE)
# Specify the primary key
dbSendQuery(Connection,'ALTER TABLE dicts.intervals ADD PRIMARY KEY ("int_id");')

# Download the lith_attributes dictsionary
Lith_attributes<-read.csv("https://macrostrat.org/api/V2/defs/lithology_attributes?all&format=csv",stringsAsFactors=FALSE)
# Write the dictionary to postgres
dbWriteTable(Connection,c("dicts","lith_attr"),value=Lith_attributes,row.names=FALSE)
# Specify the primary key
dbSendQuery(Connection,'ALTER TABLE dicts.lith_attr ADD PRIMARY KEY ("lith_att_id");')

# Download the environments dictsionary
Environments<-read.csv("https://macrostrat.org/api/V2/defs/environments?all&format=csv",stringsAsFactors=FALSE)
# Write the dictionary to postgres
dbWriteTable(Connection,c("dicts","environments"),value=Environments,row.names=FALSE)
# Specify the primary key
dbSendQuery(Connection,'ALTER TABLE dicts.environments ADD PRIMARY KEY ("environ_id");')

# Create a grain size table
GrainSize<-read.csv("https://dev.macrostrat.org/api/V2/defs/grainsizes?all&format=csv",stringsAsFactors=FALSE)
# # Write the dictionary to postgres
dbWriteTable(Connection,c("dicts","grainsize"),value=GrainSize,row.names=FALSE)
# Specify the primary key
dbSendQuery(Connection,'ALTER TABLE dicts.grainsize ADD PRIMARY KEY ("grain_id");')

#############################################################################################################
############################################### NOTES SCHEMA ################################################
#############################################################################################################
# Create the notes schema
dbSendQuery(Connection,"CREATE SCHEMA notes;")

# Create a special type of accepted notes
dbSendQuery(Connection,"CREATE TYPE note_type AS ENUM('misc','lithology','age','structure','economic','fossil');")

# Create a special type of accepted dating methods
dbSendQuery(Connection,"CREATE TYPE date_method AS ENUM('U/Pb','C14','U/Th','Ar/Ar','K/Ar','Rb/Sr','K/Ca','U/U','Kr/Kr','I/Xe','OSL','IRSL','La/Ba','La/Ce','Re/Os','Lu/Hf','Pb/Pb','Sm/Nd','Sr/Sr','Fission','Amino','Be-Cosmogenic','Al-Cosmogenic','Cl-Cosmogenic');")

# This table holdes the location and basic metadata information for miscellaneous notes, meaning notes
# That do not fit into the AZGS data standard
dbSendQuery(Connection,"CREATE TABLE notes.misc_notes (
        note_id serial PRIMARY KEY,
        collection_id integer NOT NULL REFERENCES master_table(collection_id),
        informal_name text NOT NULL,
        note_type note_type,
        azgs_path text NOT NULL UNIQUE,
        geom geometry -- if known
        );")

# This table holds the location and basic metadata information for notes meeting the AZGS standard
dbSendQuery(Connection,"CREATE TABLE notes.standard_notes (
        entry_id serial PRIMARY KEY,
        collection_id integer REFERENCES master_table(collection_id),
        station_id text NOT NULL, -- What the actual content creator called it
        early_interval_id integer REFERENCES dicts.intervals(int_id), 
        late_interval_id integer REFERENCES dicts.intervals(int_id),
        early_age numeric, -- Should add some checks to make sure number is compatible with interval
        late_age numeric,
        geom geometry NOT NULL,
        note_desc text,
        note_comments text,
        note_images integer[] --array of image_id's 
        );")

# This table desribes notes matching age estimates taken from field data
# This schema only allows a single dating type U/Pb per entry. If an individual hand
# Sample has more than one date type, then it should be listed as separate entries (i.e., diff entry_id),
# But the station_id in notes.standard_notes should be the same
dbSendQuery(Connection,"CREATE TABLE notes.standard_age (
        entry_id integer PRIMARY KEY REFERENCES notes.standard_notes(entry_id),
        early_interval_id integer NOT NULL REFERENCES dicts.intervals(int_id), 
        late_interval_id integer NOT NULL REFERENCES dicts.intervals(int_id),
        early_age numeric, -- Should add some checks to make sure number is compatible with interval
        late_age numeric,
        absolute_dates boolean NOT NULL,
        index_fossils text[],
        dated_age numeric[] CHECK (cardinality(dated_age)=cardinality(dated_age_se) IS TRUE),
        dated_age_se numeric[],
        dating_method date_method, 
        dating_laboratory text, -- where the analysis was performed
        date_comments text -- additional comments
        );")

# This table desribes notes describing the lithology of a specimen. Users can add whatever they want
# In the base sample description and comments field in notes.standard_notes, but this section will be
# limited to options from the macrostrat dictionaries. It's true that this concat string format
# is not third normal form, but works for our purposes.
dbSendQuery(Connection,"CREATE TABLE notes.standard_lithology (
        entry_id integer PRIMARY KEY REFERENCES notes.standard_notes(entry_id),
        lith_class text[],
        lith_group text[],
        lith_type text[],
        lith_names text[],
        mineral_names text[],
        sedimentary_structures text[],
        environment_name text[] 
        );")

# Create a percentage of minerals
dbSendQuery(Connection,"CREATE TABLE notes.mineral_percent (
        percent_id serial PRIMARY KEY,
        entry_id integer NOT NULL REFERENCES notes.standard_notes(entry_id),
        mineral_id integer NOT NULL REFERENCES dicts.minerals(mineral_id),
        mineral_percent numeric NOT NULL
        );")

# Create a percentage of grain size
dbSendQuery(Connection,"CREATE TABLE notes.grain_size (
        percent_id serial PRIMARY KEY,
        entry_id integer NOT NULL REFERENCES notes.standard_notes(entry_id),
        grain_id integer NOT NULL REFERENCES dicts.grainsize(grain_id),
        grain_percent numeric NOT NULL
        );")

#############################################################################################################
################################################# CLEAN UP ##################################################
#############################################################################################################
dbSendQuery(Connection,"VACUUM ANALYZE;")
