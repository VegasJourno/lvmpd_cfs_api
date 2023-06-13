options(scipen = 999)

lvmpd_all <- read.csv("C:/Users/sdavidson/Downloads/LVMPD_Calls_For_Service_All.csv") %>% 
  clean_names()

lvmpd_all_clean <- lvmpd_all %>% 
  select(incident_number = incidentnumber,
         incident_date = incidentdate,
         classification,
         incident_type_code,
         incident_type_description = incidenttypedescription,
         address = location,
         disposition,
         latitude,
         longitude,
         weekday,
         hour,
         month,
         year,
         zip_code = zipcode,
         geometry_x = x,
         geometry_y = y) %>% 
  mutate(incident_date = ymd_hms(incident_date)) %>% 
  #Format to our timezone, includes daylight savings
  mutate(incident_date = format(incident_date, tz="America/Los_Angeles",usetz=TRUE)) %>% 
  mutate(incident_date = ymd_hms(incident_date)) %>% 
  distinct() %>%
  mutate_all(as.character)

###
###

lvmpd_2019_clean <- lvmpd_all_clean %>% 
  filter(year == "2019")

lvmpd_2020_clean <- lvmpd_all_clean %>% 
  filter(year == "2020")

lvmpd_2021_clean <- lvmpd_all_clean %>% 
  filter(year == "2021")

lvmpd_2022_clean <- lvmpd_all_clean %>% 
  filter(year == "2022")

lvmpd_2023_clean <- lvmpd_all_clean %>% 
  filter(year == "2023")

###
###

write.csv(lvmpd_2019_clean,
          "C:/Users/sdavidson/Downloads/lvmpd_cfs_2019.csv",
          row.names = FALSE)

write.csv(lvmpd_2020_clean,
          "C:/Users/sdavidson/Downloads/lvmpd_cfs_2020.csv",
          row.names = FALSE)

write.csv(lvmpd_2021_clean,
          "C:/Users/sdavidson/Downloads/lvmpd_cfs_2021.csv",
          row.names = FALSE)

write.csv(lvmpd_2022_clean,
          "C:/Users/sdavidson/Downloads/lvmpd_cfs_2022.csv",
          row.names = FALSE)

write.csv(lvmpd_2023_clean,
          "C:/Users/sdavidson/Downloads/lvmpd_cfs_2023.csv",
          row.names = FALSE)
