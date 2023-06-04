#Libraries
library(tidyverse)
library(rjson)
library(httr)
library(janitor)
library(googledrive)
library(mailR)

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
  #Get into date format for Rbind later
  mutate(incident_date = ymd_hms(incident_date))


#Drop the columns I don't want for bind later
lvmpd_cfs_master <- lvmpd_cfs_master %>% 
  select(-c(objectid, day, updated_date))

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
#UPDATE ROLLING 2023 RESULTS ON GITHUB

#Write the CSV name (same as before)
lvmpd_cfs_2023_path <- "data/lvmpd_cfs_2023.csv"

#Load in Master File from repository
lvmpd_cfs_2023 <- read_csv("data/lvmpd_cfs_2023.csv") %>%
  mutate_all(as.character)

#Make all the data "characters"                      
lvmpd_cfs_master <- lvmpd_cfs_master %>%
  mutate_all(as.character)

#Rbind the newest results to it
lvmpd_cfs_2023_new <- rbind(lvmpd_cfs_2023,
                             lvmpd_cfs_master) %>% 
  #Delete any repeat requests
  distinct(incident_number, .keep_all = TRUE)

#Write new CSV for repository
write.csv(lvmpd_cfs_2023_new, 
          lvmpd_cfs_2023_path, 
          row.names=FALSE)

####
####
####
#UPLOAD ROLLING 2023 RESULTS TO GOOGLE DRIVE
DRIVE_JSON <- Sys.getenv("DRIVE_JSON")
DRIVE_FOLDER <- Sys.getenv("DRIVE_FOLDER")

googledrive::drive_auth(path = DRIVE_JSON)
td <- drive_get(DRIVE_FOLDER)

#Upload that Master 2023 CSV to Google drive
drive_put(lvmpd_cfs_2023_path, 
          name =  "lvmpd_cfs_2023", 
          type = "spreadsheet", 
          path=as_id(td))