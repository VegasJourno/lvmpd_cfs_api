#Libraries
library(tidyverse)
library(rjson)
library(httr)
library(janitor)
library(googledrive)
library(mailR)
library(rmarkdown)

#Get the DateTime that file was exported
ExportDateTime <- format((Sys.time() - (6*60*60)), 
                         "%Y-%m-%d_%I%p")

#Create main dataframe
lvmpd_cfs_main <- NULL

#Build sequence of days, can only be between 1 and 31. 
##This appears to work, even if day isn't represented in dataframe
x <- seq(1,31)

#Create 7 hours to subtract, due to UTC time zone
hrs <- 7 * 60 * 60

#Turn off Scientific Notation
options(scipen = 999)

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
  lvmpd_cfs_main <- rbind(lvmpd_cfs_main, 
                          lvmpd_DF)
  
  #Wait 1 second before running again
  Sys.sleep(1)
}

####
####
####

#Fix the date/time columns
lvmpd_cfs_main <- lvmpd_cfs_main %>% 
  #Get only first 10 characters
  mutate(incident_date = substr(incident_date, 1, 10),
         updated_date = substr(updated_date, 1, 10)) %>% 
  #Convert into correct date
  mutate(incident_date = as.POSIXct(as.numeric(incident_date), 
                                    origin="1970-01-01")) %>% 
  #Get into date format for Rbind later
  mutate(incident_date = ymd_hms(incident_date)) %>% 
  mutate(incident_date = (incident_date - hrs))


#Drop the columns I don't want for bind later
lvmpd_cfs_main <- lvmpd_cfs_main %>% 
  select(-c(objectid, day, updated_date))

##Create the CSV name based on original run date/time
lvmpd_cfs_main_path <- paste0("data/lvmpd_cfs_",
                              ExportDateTime,
                              ".csv")

#Save output DataFrame
write.csv(lvmpd_cfs_main, 
          lvmpd_cfs_main_path, 
          row.names=FALSE)

####
####
####
#UPDATE ROLLING 2023 RESULTS ON GITHUB

#Write the CSV name (same as before)
lvmpd_cfs_2023_path <- "data/lvmpd_cfs_2023.csv"

#Load in Rolling File from repository
lvmpd_cfs_2023 <- read_csv("data/lvmpd_cfs_2023.csv") %>%
  mutate_all(as.character)

#Make all the data "characters"                      
lvmpd_cfs_main <- lvmpd_cfs_main %>%
  mutate_all(as.character)

#Rbind the newest results to it
lvmpd_cfs_2023_new <- rbind(lvmpd_cfs_2023,
                            lvmpd_cfs_main) %>% 
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

drive_put(lvmpd_cfs_2023_path, 
          name =  "lvmpd_cfs_2023", 
          type = "spreadsheet", 
          path=as_id(td))

####
####
####

#RENDER REPORT & SHARE VIA EMAIL
docx_report_path <- paste0("data/lvmpd_cfs_api_", 
                           ExportDateTime, 
                           '.docx', sep='')

rmarkdown::render("lvmpd_cfs_markdown.Rmd",
                  output_file = docx_report_path)


####
####
####

#Read in the environment Secret objects
GMAIL_SENDER <- Sys.getenv("GMAIL_SENDER")
GMAIL_RECIPIENT <- Sys.getenv("GMAIL_RECIPIENT")
GMAIL_USER <- Sys.getenv("GMAIL_USER")
GMAIL_PASS <- Sys.getenv("GMAIL_PASS")

#Email the Rmarkdown report
send.mail(from = GMAIL_SENDER,
          to = c("michaeldmedia@gmail.com", "bclarkson@reviewjournal.com"),
          subject = paste0("Calls For Service - ", ExportDateTime),
          body = "See attached report.",
          smtp = list(host.name = "smtp.gmail.com", port = 465, 
                      user.name = GMAIL_USER, 
                      #Generated app password thru Gmail security settings
                      passwd = GMAIL_PASS, 
                      ssl = TRUE),
          authenticate = TRUE,
          send = TRUE,
          attach.files = c(docx_report_path),
          file.names = c("lvmpd_cfs_summary.docx"))

#Email notification of success
send.mail(from = GMAIL_SENDER,
          to = c("michaeldmedia@gmail.com", "bclarkson@reviewjournal.com"),
          subject = paste0("Success: LVMPD CFS Export - ", ExportDateTime),
          body = "Github Action ran successfully. See attached report.",
          smtp = list(host.name = "smtp.gmail.com", port = 465, 
                      user.name = GMAIL_USER, 
                      #Generated app password thru Gmail security settings
                      passwd = GMAIL_PASS, 
                      ssl = TRUE),
          authenticate = TRUE,
          send = TRUE,
          attach.files = c(docx_report_path),
          file.names = c("lvmpd_cfs_summary.docx"))
