
import arcpy
from arcpy import env

#Enter path to data 
env.workspace = "C:/Users/Vricigliano/Desktop/Sample GDB"
env.overwriteOutput= True

#A custom function to write GeoJSON for all features
#Enter geodatabase name 
gdbName = "Helvetia_ncgmp09"
	
#Convert from fetaure to geoJSON
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/CartographicLines","/JSON/CartographicLines.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/ContactsAndFaults","/JSON/ContactsAndFaults.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/DataSourcePolys","/JSON/DataSourcePolys.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/GenericPoints","/JSON/GenericPoints.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/GenericSamples","/JSON/GenericSamples.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/GeochronPoints","/JSON/GeochronPoints.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/GeologicLines","/JSON/GeologicLines.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/IsoValueLines","/JSON/IsoValueLines.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/MapUnitPoints","/JSON/MapUnitPoints.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/MapUnitPolys","/JSON/MapUnitPolys.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/MapUnitPolysAnno","/JSON/MapUnitPolysAnno.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/OrientationDataPointsAnno","/JSON/OrientationDataPointsAnno.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/OrientationPoints","/JSON/OrientationPoints.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/OtherPolys","/JSON/OtherPolys.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")
arcpy.FeaturesToJSON_conversion("/" + gdbName + ".gdb/GeologicMap/Stations","/JSON/Stations.json","NOT_FORMATTED","NO_Z_VALUES","NO_M_VALUES")


#Feature to shapefile
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/MapUnitPoints","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/IsoValueLines","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/GeologicLines","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/GeochronPoints","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/GenericSamples","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/GenericPoints","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/OrientationPoints","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/OtherPolys","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/Stations","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/DataSourcePolys","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/OrientationDataPointsAnno","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/ContactsAndFaults","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/MapUnitPolysAnno","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/CartographicLines","/Shapefiles")
arcpy.FeatureClassToShapefile_conversion("/" + gdbName + ".gdb/GeologicMap/MapUnitPolys","/Shapefiles")

#Make a layer from the feature class
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/MapUnitPoints","MapUnitPoints_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/CartographicLines","CartographicLines_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/ContactsAndFaults","ContactsAndFaults_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/DataSourcePolys","DataSourcePolys_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/GenericPoints","GenericPoints_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/GenericSamples","GenericSamples_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/GeochronPoints","GeochronPoints_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/GeologicLines","GeologicLines_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/IsoValueLines","IsoValueLines_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/MapUnitPolys","MapUnitPolys_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/MapUnitPolysAnno","MapUnitPolysAnno_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/OrientationDataPointsAnno","OrientationDataPointsAnno_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/OrientationPoints","OrientationPoints_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/OtherPolys","OtherPolys_lyr")
arcpy.MakeFeatureLayer_management("/" + gdbName + ".gdb/GeologicMap/Stations","Stations_lyr")

   
#Convert to kml
arcpy.LayerToKML_conversion("MapUnitPoints_lyr","/KML/MapUnitPoints.kmz")
arcpy.LayerToKML_conversion("CartographicLines_lyr","/KML/CartographicLines.kmz")
arcpy.LayerToKML_conversion("ContactsAndFaults_lyr","/KML/ContactsAndFaults.kmz")
arcpy.LayerToKML_conversion("DataSourcePolys_lyr","/KML/DataSourcePolys.kmz")
arcpy.LayerToKML_conversion("GenericPoints_lyr","/KML/GenericPoints.kmz")
arcpy.LayerToKML_conversion("GenericSamples_lyr","/KML/GenericSamples.kmz")
arcpy.LayerToKML_conversion("GeochronPoints_lyr","/KML/GeochronPoints.kmz")
arcpy.LayerToKML_conversion("GeologicLines_lyr","/KML/GeologicLines.kmz")
arcpy.LayerToKML_conversion("IsoValueLines_lyr","/KML/IsoValueLines.kmz")
arcpy.LayerToKML_conversion("MapUnitPolys_lyr","/KML/MapUnitPolys.kmz")
arcpy.LayerToKML_conversion("MapUnitPolysAnno_lyr","/KML/MapUnitPolysAnno.kmz")
arcpy.LayerToKML_conversion("OrientationDataPointsAnno_lyr","/KML/OrientationDataPointsAnno.kmz")
arcpy.LayerToKML_conversion("OrientationPoints_lyr","/KML/OrientationPoints_lyr.kmz")
arcpy.LayerToKML_conversion("OtherPolys_lyr","/KML/OtherPolys_lyr.kmz")
arcpy.LayerToKML_conversion("Stations_lyr","/KML/Stations_lyr.kmz")


 
 
