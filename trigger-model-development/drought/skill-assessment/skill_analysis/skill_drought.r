rm(list=ls())
library(tidyverse)
library(lubridate)
library(sf)
library(leaflet)
library(readr)
library(httr)
library(sp)
library(lubridate)


onedrive_folder <- "c:/Users/pphung/Rode Kruis"


# read admin and livelihoodzone boundaries 
zwe_lhz <- st_read(sprintf('%s/510 - Data preparedness and IBF - [PRJ] FbF - Zimbabwe - Danish Red Cross/3. Data - Hazard exposure, vulnerability/zwe_livelihoodzones/ZW_LHZ_2011/ZW_LHZ_2011_fixed.shp',
                           onedrive_folder))
zwe <- st_read(sprintf('%s/510 - Data preparedness and IBF - [PRJ] FbF - Zimbabwe - Danish Red Cross/3. Data - Hazard exposure, vulnerability/Admin/zwe_admbnda_adm2_zimstat_ocha_20180911/zwe_admbnda_adm2_zimstat_ocha_20180911.shp',
                       onedrive_folder))
zwe <- zwe %>%
  dplyr::select(ADM1_PCODE,ADM2_PCODE,ADM0_EN)
zwe_lhz <- zwe_lhz %>%
  dplyr::mutate(ADM0_EN=COUNTRY) %>%
  dplyr::select(LZCODE)

admin_all <- st_union(zwe_lhz, zwe, by_feature=FALSE) %>%
  dplyr::select(ADM1_PCODE,ADM2_PCODE,ADM0_EN,LZCODE)



# load and calculate crop yield anomaly
yield_thr = -1

yield <- read.csv(sprintf('%s/510 - Data preparedness and IBF - [PRJ] FbF - Zimbabwe - Danish Red Cross/3. Data - Hazard exposure, vulnerability/zwe_cropyield/all_yield_maize_major.csv',onedrive_folder))

mean_sd <- yield %>% 
  group_by(pcode) %>% 
  summarise(mean = mean(yield,na.rm=TRUE), sd = sd(yield,na.rm=TRUE)) # calculate mean and standard deviation along the year axis
yield <- yield %>%
  left_join(mean_sd,by='pcode')
yield$yield_anomaly <- (yield$yield-yield$mean)/yield$sd       # calculate CYA
yield$drought <- ifelse(yield$yield_anomaly < yield_thr, 1, 0)  # mark if it is drought or not (= if the CYA exceeds the threshold)

yield = subset(yield, select=-c(mean,sd))

df_all <- admin_all %>%
  left_join(yield,by=c('LZCODE'='pcode'))


# load bio-indicator
spi_zwe <- read.csv(sprintf('%s/510 - Data preparedness and IBF - [PRJ] FbF - Zimbabwe - Danish Red Cross/3. Data - Hazard exposure, vulnerability/zwe_spi/zwe_spi3.csv',onedrive_folder))%>%
  mutate(date=ymd(as.Date(date))) %>%
  mutate(year=year(date))
dmp_zwe <- read.csv(sprintf('%s/510 - Data preparedness and IBF - [PRJ] FbF - Zimbabwe - Danish Red Cross/3. Data - Hazard exposure, vulnerability/zwe_dmp/all_dmp.csv',onedrive_folder))%>%
  mutate(date=ymd(as.Date(date))) %>%
  mutate(year=year(date))
ipc_zwe <- read.csv(sprintf('%s/510 - Data preparedness and IBF - [PRJ] FbF - Zimbabwe - Danish Red Cross/3. Data - Hazard exposure, vulnerability/zwe_ipc/zwe_ipc.csv',onedrive_folder))%>%
  mutate(date=ymd(as.Date(Date)))
enso <- read.csv(sprintf("%s/510 - Data preparedness and IBF - [RD] Impact-based forecasting/General_Data/elnino/ENSO.csv",onedrive_folder)) %>%
  gather("MON",'ENSO',-Year) %>% 
  arrange(Year) %>%
  dplyr::mutate(date=seq(as.Date("1950/01/01"), by = "month", length.out = 852))%>%
  filter(date>= as.Date("1980/01/01"))


# SPI
spi_thr = -0.65

spi_zwe_mean <- spi_zwe %>%        # take mean value among the 3 months of the year
  group_by(year,livelihoodzone) %>%
  summarise(spi_mean=mean(SPI3))  ### to replace column name when reading different SPI/ SPEI
spi_zwe_mean <- spi_zwe_mean %>%
  mutate(spi_drought = ifelse(spi_mean>spi_thr, 0, 1))  # binary logic if the index is higher than the threshold: 0, else 1

# df_all <- df_all %>%       # join to a big table
#     left_join(spi_zwe_mean,by=c('LZCODE'='livelihoodzone'))
# write.csv(df_all, './output/combined_indicators.csv')

yield_spi <- merge(spi_zwe_mean, yield, by.x=c("livelihoodzone","year"), by.y=c("pcode","year")) %>%
  left_join(admin_all,by=c('livelihoodzone'='LZCODE'))
yield_spi <- yield_spi %>% 
  group_by(year,ADM2_PCODE) %>%
  summarise(spi_drought_adm=max(spi_drought),drought_adm=max(drought,na.rm=TRUE)) # get droughts per adm2

scores_yield_spi <- yield_spi %>%
  mutate(
    hit = spi_drought_adm & drought_adm,                     # hit when it's drought and crop loss
    false_alarm = (spi_drought_adm==1) & (drought_adm==0),   # false alarm when it's drought but not crop loss
    missed = (spi_drought_adm==0) & (drought_adm==1),        # missed when it's not drought but crop loss
    cor_neg = (spi_drought_adm==0) & (drought_adm==0)        
  ) %>%
  group_by(ADM2_PCODE) %>%
  summarise(
    hits = sum(hit),
    false_alarms = sum(false_alarm),
    triggered = hits + false_alarms,
    POD = hits/(hits+sum(missed)),
    FAR = false_alarms/(hits+false_alarms)
  )
write.csv(scores_yield_spi, './output/scores_yield_spi.csv')



# DMP
dmp_thr = 70

dmp_zwe_mean <- dmp_zwe[months(dmp_zwe$date) %in% month.name[1:3],] %>% # subset Jan, Feb, Mar from 1983-2012
  group_by(year,pcode) %>%
  summarise(dmp_mean=mean(dmp))
dmp_zwe_mean <- dmp_zwe_mean %>%
  mutate(dmp_drought = ifelse(dmp_mean>dmp_thr, 0, 1))  # binary logic if the index is higher than the threshold: 0, else 1

# df_all <- df_all %>%
#   left_join(dmp_zwe_mean,by=c('LZCODE'='pcode'))

yield_dmp <- merge(dmp_zwe_mean, yield, by=c("pcode","year")) %>% 
  left_join(admin_all,by=c('pcode'='LZCODE')) %>% 
  group_by(year,ADM2_PCODE) %>%
  summarise(dmp_drought_adm=max(dmp_drought),drought_adm=max(drought,na.rm=TRUE))

scores_yield_dmp <- yield_dmp %>%
  mutate(
    hit = dmp_drought_adm & drought_adm,                     # hit when it's drought and crop loss
    false_alarm = (dmp_drought_adm==1) & (drought_adm==0),   # false alarm when it's drought but not crop loss
    missed = (dmp_drought_adm==0) & (drought_adm==1),        # missed when it's not drought but crop loss
    cor_neg = (dmp_drought_adm==0) & (drought_adm==0)        
  ) %>%
  group_by(ADM2_PCODE) %>%
  summarise(
    hits = sum(hit),
    false_alarms = sum(false_alarm),
    triggered = hits + false_alarms,
    POD = hits/(hits+sum(missed)),
    FAR = false_alarms/(hits+false_alarms)
  )
write.csv(scores_yield_dmp, './output/scores_yield_dmp.csv')





