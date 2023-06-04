#Libraries
library(tidyverse)
library(rjson)
library(httr)
library(janitor)
library(googledrive)
library(mailr)

#Create master dataframe
lvmpd_cfs_master <- NULL

#Build sequence of days, can only be between 1 and 31. 
##This appears to work, even if day isn't represented in dataframe
x <- seq(1,31)

####
####
####

#For Loop
for (i in x) {
  
  #Create URL
  ##It wants a range of two days, but I only want 1 day, so I feed in the "day" value twice
  
  url <- paste0("https://services.arcgis.com/jjSk6t82vIntwDbs/arcgis/rest/services/LVMPD_Calls_For_Service_30_Days/FeatureServer/0/query?where=%20(Day%20%3D%20",
                i,
                "%20OR%20Day%20%3D%20",
                i,
                ")%20&outFields=*&outSR=4326&f=json")
  
  #Load in the data via API Call
  url_get <- httr::GET(url)
  
  lvmpd_content <- httr::content(url_get, 
                                 as = "text")
  
  #Start parsing JSON file
  ##Be sure to flatten it
  lvmpd_JSON <- jsonlite::fromJSON(lvmpd_content, 
                                   flatten = TRUE)
  
  #Turn into dataframe
  lvmpd_DF <- (lvmpd_JSON$features) %>% 
    as.data.frame() %>% 
    #Start cleaning column names
    clean_names()
  
  #Finish cleaning column names
  colnames(lvmpd_DF) <- gsub("attributes_", "",
                             colnames(lvmpd_DF))
  
  #Bind the new scrape's data
  lvmpd_cfs_master <- rbind(lvmpd_cfs_master, 
                            lvmpd_DF)
  
  #Wait 1 second before running again
  Sys.sleep(1)
}

####
####
####

#Fix the date/time columns
lvmpd_cfs_master <- lvmpd_cfs_master %>% 
  #Get only first 10 characters
  mutate(incident_date = substr(incident_date, 1, 10),
         updated_date = substr(updated_date, 1, 10)) %>% 
  #Convert into correct date
  mutate(incident_date = as.POSIXct(as.numeric(incident_date), 
                                    origin="1970-01-01")) %>% 
  mutate(updated_date = as.POSIXct(as.numeric(updated_date), 
                                   origin="1970-01-01"))

#Drop the objectid columns
lvmpd_cfs_master <- lvmpd_cfs_master %>% 
  select(-objectid)

####
####
####

#Save result as a CSV
currentDate <- Sys.Date() %>% 
  as.character() %>% 
  str_replace_all("-","_")

lvmpd_cfs_path <- paste0("data/lvmpd_cfs_30day_",
                         currentDate,
                         ".csv")

#Save output DataFrame
write.csv(lvmpd_cfs_master, 
          lvmpd_cfs_path, 
          row.names=FALSE)

####
####
####

#UPLOAD DAILY RESULTS TO GOOGLE DRIVE
DRIVE_JSON <- Sys.getenv("DRIVE_JSON")
DRIVE_FOLDER <- Sys.getenv("DRIVE_FOLDER")

googledrive::drive_auth(path = DRIVE_JSON)
td <- drive_get(DRIVE_FOLDER)

#Export the ALL scrape into Google Drive for historical purposes
drive_put(lvmpd_cfs_path, 
          name = 
            paste0("lvmpd_cfs_30day_", currentDate), 
          type = "spreadsheet", 
          path=as_id(td))