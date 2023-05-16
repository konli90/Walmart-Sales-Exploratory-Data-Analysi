#loading libraries
library(dplyr)
library(readr)
library(readxl)
library(tidyverse)
library(tidyr)
library(gdata)
library(xlsx)
library(tm)
library(data.table)
library(fmsb)
library(reshape2)
library(magrittr)
library(lubridate)
library(janitor)
library(httr)
library(jsonlite)
library(robotoolbox)

#set working directory
setwd('C:\\power bi')

#kobotoolbox settings

# Define the API endpoint URL
endpoint_url <- paste0("https://kc.kobotoolbox.org/api/v1/data/123456789")

# Get a token
token <- kobo_token(username = "abcde", password = "abc123", 
                    url = "https://kf.kobotoolbox.org")

# Make a GET request to the API endpoint
response <- GET(endpoint_url, add_headers(Authorization = paste0("Token ", token)))

# Check the status code of the response
status_code(response)

# Decode the response content
response_content <- content(response, as = "text", encoding = "UTF-8")

# Parse the response content into a data frame
submissions_df <- fromJSON(response_content, flatten = TRUE)

data <- as.data.frame(submissions_df)

# remove the other dataframes
rm(list=c('response', 'submissions_df', 'response_content', 'endpoint_url', 'token'))

# select columns
data %<>% select(c(today, labname, facility_type,'hub/samples_received','hub/samples_rejected','hub/lims_entries',
                   'hub/samples_sent_ml','hub/results_printed','hub/results_dispatched',
                   'ml/ml_received','ml/ml_rejected','ml/ml_entered',
                   'ml/ml_unentered','ml/ml_unprocessed', 'ml/tests/abbot_tests','ml/tests/abbot_failed',
                   'ml/tests/hologic_tests','ml/tests/hologic_failed','ml/tests/alinity_tests',
                   'ml/tests/alinity_failed','ml/tests/roche_tests','ml/tests/roche_failed',
                   'ml/ml_approved','ml/ml_unapproved','ml/ml_results_printed','ml/ml_results_dispatched'))

# rename columns
names(data) <- c('today', 'labname', 'facility_type', 'hub.samples_received', 'hub.samples_rejected', 
                 'hub.lims_entries','hub.samples_sent_ml', 'hub.results_printed', 'hub.results_dispatched',
                 'ml.ml_received', 'ml.ml_rejected', 'ml.ml_entered', 'ml.ml_unentered', 
                 'ml.ml_unprocessed','ml.tests.abbot_tests', 'ml.tests.abbot_failed', 
                 'ml.tests.hologic_tests', 'ml.tests.hologic_failed', 
                 'ml.tests.alinity_tests','ml.tests.alinity_failed', 'ml.tests.roche_tests', 'ml.tests.roche_failed',
                 'ml.ml_approved', 'ml.ml_unapproved','ml_results_printed','ml_results_dispatched')

# change Molecular lab to Molecular Lab in facility type
data$facility_type[data$facility_type == '2'] <- 'Molecular Lab'
data$facility_type[data$facility_type == '1'] <- 'Hub'

# rename laboratory names
data$labname[data$labname == "DreamBlantyre"] <- "Dream Blantyre"
data$labname[data$labname == "MzuzuCentral"] <- "Mzuzu Central"
data$labname[data$labname == "DreamBalaka"] <- "Dream Balaka"
data$labname[data$labname == "Mzuzu Health Centre"] <- "Mzuzu"
data$labname[data$labname == "Mzimba District Hospital"] <- "Mzimba"
data$labname[data$labname == "Zomba Central"] <- "Zomba"
data$labname[data$labname == "Phalombe District Hospital"] <- "Phalombe"
data$labname[data$labname == "Bwaila Hospital"] <- "Bwaila"
data$labname[data$labname == "Queen Elizabeth Central Hospital"] <- "QECH"
data$labname[data$labname == "Kamuzu Central Hospital"] <- "KCH"

# convert columns to intergers
data$hub.samples_received <- as.integer(data$hub.samples_received)
data$hub.samples_rejected <- as.integer(data$hub.samples_rejected)
data$hub.lims_entries <- as.integer(data$hub.lims_entries)
data$hub.samples_sent_ml <- as.integer(data$hub.samples_sent_ml)
data$hub.results_printed <- as.integer(data$hub.results_printed)
data$hub.results_dispatched <- as.integer(data$hub.results_dispatched)
data$ml.ml_received <- as.integer(data$ml.ml_received)
data$ml.ml_rejected <- as.integer(data$ml.ml_rejected)
data$ml.ml_entered <- as.integer(data$ml.ml_entered)
data$ml.ml_unentered <- as.integer(data$ml.ml_unentered)
data$ml.ml_unprocessed <- as.integer(data$ml.ml_unprocessed)
data$ml.tests.abbot_tests <- as.integer(data$ml.tests.abbot_tests)
data$ml.tests.abbot_failed <- as.integer(data$ml.tests.abbot_failed)
data$ml.tests.hologic_tests <- as.integer(data$ml.tests.hologic_tests)
data$ml.tests.hologic_failed <- as.integer(data$ml.tests.hologic_failed)
data$ml.tests.alinity_tests <- as.integer(data$ml.tests.alinity_tests)
data$ml.tests.alinity_failed <- as.integer(data$ml.tests.alinity_failed)
data$ml.tests.roche_tests <- as.integer(data$ml.tests.roche_tests)
data$ml.tests.roche_failed <- as.integer(data$ml.tests.roche_failed)
data$ml.ml_approved <- as.integer(data$ml.ml_approved)
data$ml.ml_unapproved <- as.integer(data$ml.ml_unapproved)
data$ml_results_printed <- as.integer(data$ml_results_printed)
data$ml_results_dispatched <- as.integer(data$ml_results_dispatched)


#convert date to datetime
data$today <- as.Date(data$today)

# convert all dates to friday which is the day data has to be uploaded in the kobotoolbox
data$prev_friday <- as.Date(as.POSIXct(data$today) - (as.numeric(data$today) + 6) %% 7 * 86400, origin = "1970-01-01")

# calculate week number
data <- data |>
  mutate(date = as.Date(prev_friday, format = "%Y-%m-%d")) %>%
  mutate(yearweek = as.character(strftime(date, format = "%Y%_%V")))

# create a week range
date_range <- function(date) {
  day_of_week <- weekdays(date)
  if (day_of_week == "Saturday") {
    start <- date
    end <- date + days(5)
    return(paste(start, "-", end, sep = " "))
  } else if (day_of_week == "Sunday") {
    start <- date - days(1)
    end <- date + days(4)
    return(paste(start, "-", end, sep = " "))
  } else if (day_of_week == "Monday") {
    start <- date - days(2)
    end <- date + days(3)
    return(paste(start, "-", end, sep = " "))
  } else if (day_of_week == "Tuesday") {
    start <- date - days(3)
    end <- date + days(2)
    return(paste(start, "-", end, sep = " "))
  } else if (day_of_week == "Wednesday") {
    start <- date - days(4)
    end <- date + days(1)
    return(paste(start, "-", end, sep = " "))
  } else if (day_of_week == "Thursday") {
    start <- date - days(5)
    end <- date
    return(paste(start, "-", end, sep = " "))
  } else if (day_of_week == "Friday") {
    start <- date - days(6)
    end <- date
    return(paste(start, "-", end, sep = " "))
  }
}

data <- mutate(data, yearweek = sapply(data$prev_friday, date_range))

# select columns for hub
data_hub <- data[data$facility_type == 'Hub', ]
data_hub %<>% select(c(prev_friday, yearweek,labname, facility_type, hub.samples_received, hub.samples_rejected, 
                       hub.lims_entries,hub.samples_sent_ml, hub.results_printed, hub.results_dispatched))  


# select samples received for hub
data_hub_received <- data_hub
data_hub_received %<>% select(c(yearweek, labname, hub.samples_received))

hub_received <- data_hub_received |>
  group_by(labname, yearweek) |> 
  summarize(total_received = sum(hub.samples_received))

# change columns to rows
hub_received_wide <- pivot_wider(hub_received, names_from = labname, values_from = total_received)

# replace hub_received_wide dataframe NA with 0
hub_received_wide <- hub_received_wide |>
  mutate_at(c('Area25', 'Blantyre','Balaka','Bwaila', 'Chikwawa', 'Chiradzulu','Chitipa','Dedza', 'Dowa', 'Karonga',
              'Kasungu', 'Machinga', 'Mangochi', 'Mchinji', 'Mitundu', 'Mulanje', 'Mwanza', 'Mzuzu', 'Neno', 'Nkhatabay',
              'Nkhotakota','Ntchisi', 'Rumphi', 'Ntcheu', 'Salima'), ~replace_na(.,0))

# sort dataframe by week
hub_received_wide <- hub_received_wide %>% arrange(desc(yearweek))

# select top 5 rows
hub_received_wide <- head(hub_received_wide, 5)

# select columns for molecular lab
data_molecular <- data[data$facility_type == 'Molecular Lab', ]
data_molecular %<>% select(c(prev_friday, yearweek,labname, facility_type,ml.ml_received, ml.ml_rejected, 
                             ml.ml_entered, ml.ml_unentered, ml.ml_unprocessed,ml.tests.abbot_tests,ml.tests.abbot_failed, 
                             ml.tests.hologic_tests, ml.tests.hologic_failed, ml.tests.alinity_tests,ml.tests.alinity_failed,
                             ml.tests.roche_tests, ml.tests.roche_failed,ml.ml_approved, ml.ml_unapproved,
                             ml_results_printed,ml_results_dispatched))


# replace data_molecular dataframe NA with 0
data_molecular <- data_molecular |>
  mutate_at(c('ml.ml_received', 'ml.ml_rejected', 'ml.ml_entered', 'ml.ml_unentered', 'ml.ml_unprocessed',
              'ml.tests.abbot_tests','ml.tests.abbot_failed','ml.tests.hologic_tests', 'ml.tests.hologic_failed', 
              'ml.tests.alinity_tests','ml.tests.alinity_failed','ml.tests.roche_tests', 'ml.tests.roche_failed',
              'ml.ml_approved', 'ml.ml_unapproved','ml_results_printed','ml_results_dispatched'), ~replace_na(.,0))

# add total tests for ML
data_molecular$ml_total_tests <- rowSums(data_molecular[, c('ml.tests.abbot_tests', 'ml.tests.roche_tests', 
                                                            'ml.tests.hologic_tests', 'ml.tests.alinity_tests')])

# number of errors
# ml_errors <- data_molecular

data_molecular$total_errors <- rowSums(data_molecular[, c('ml.tests.abbot_failed', 'ml.tests.roche_failed', 
                                                          'ml.tests.hologic_failed', 'ml.tests.alinity_failed')])

#  ml_errors %<>% select(c(yearweek, yearweek2,  labname, ml.ml_rejected, ml.tests.abbot_failed, ml.tests.roche_failed, 
#                         ml.tests.hologic_failed, ml.tests.alinity_failed, total_errors))

# select total tests for ML
data_molecular_tests <- data_molecular
data_molecular_tests %<>% select(c(yearweek, labname, ml_total_tests))

# transpose ML tests
ml_tests <- data_molecular_tests %>%
  group_by(labname, yearweek) %>% 
  summarize(total_tests = sum(ml_total_tests))

# change columns to rows
ml_total_tests_wide <- pivot_wider(ml_tests, names_from = labname, values_from = total_tests)

# replace ml_total_tests_wide dataframe NA with 0
ml_total_tests_wide <- ml_total_tests_wide %>%
  mutate_at(c('Dream Balaka', 'Dream Blantyre', 'Nsanje', 'QECH', 'Mzuzu Central',
              'Mzimba', 'Thyolo', 'Zomba', 'KCH', 'Phalombe', 'PIH'), ~replace_na(.,0))

# sort dataframe in descending order
ml_total_tests_wide <- ml_total_tests_wide %>% arrange(desc(yearweek))

# select top 5 rows
ml_total_tests_wide <- head(ml_total_tests_wide, 5) 

# change columns to rows
#ml_total_tests_wide2 <- pivot_wider(ml_tests, names_from = yearweek2, values_from = total_tests)
#ml_total_tests_wide2[is.na(ml_total_tests_wide2)] <- 0

#rename column to today
data_hub <- data_hub %>% rename(today = prev_friday)
data_molecular <- data_molecular %>% rename(today = prev_friday)

# save the datasets  
write.xlsx(data_hub, file = './datasets/data_hub.xlsx', sheetName = 'data_hub')
write.xlsx(data_hub_received, file = './datasets/data_hub_received.xlsx', sheetName = 'data_hub_received')
write.xlsx(data_molecular, file = './datasets/data_molecular.xlsx', sheetName = 'data_molecular')
write.xlsx(data_molecular_tests, file = './datasets/data_molecular_tests.xlsx', sheetName = 'data_molecular_tests')
write.xlsx(hub_received_wide, file = './datasets/hub_received_wide.xlsx', sheetName = 'hub_received_wide')
write.xlsx(ml_total_tests_wide, file = './datasets/ml_total_tests_wide.xlsx', sheetName = 'ml_total_tests_wide')
#write.xlsx(ml_total_tests_wide2, file = './datasets/ml_total_tests_wide2.xlsx', sheetName = 'ml_total_tests_wide2')