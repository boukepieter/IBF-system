# -*- coding: utf-8 -*-
"""
Created on Fri Mar 12 12:49:09 2021

@author: BOttow
"""

import xarray as xr
import pandas as pd
import os
import re

# functions
def glofas_extract_date(ds, time, st_lat, st_lon, deltax, ensemble):
    df=ds['dis24'].sel(latitude=slice(st_lat+deltax,st_lat-deltax), 
                       longitude=slice(st_lon-deltax,st_lon+deltax),
                       time = time).values.flatten()
    d = {'date' : time, 'ensemble' : ensemble, 'discharge' : df}
    df_stations = pd.DataFrame(data = d)
    return df_stations

def glofas_extract_file(file, st_lat, st_lon, deltax, ensemble):
    ds = xr.open_dataset(file,engine='cfgrib')
    times = ds['time'].data
    df_stations = glofas_extract_date(ds, times[0], st_lat, st_lon, deltax, ensemble)
    for time in times[1:]:
        #print(time)
        df_stations_add = glofas_extract_date(ds, time, st_lat, st_lon, deltax, ensemble)
        df_stations = pd.concat([df_stations, df_stations_add], axis=0, sort=False)
    return df_stations

def glofas_extract_station(directory, files, st_lat, st_lon, deltax, ensemble):
    print(files[0])
    df_station = glofas_extract_file("%s/%s" % (directory, files[0]), st_lat, st_lon, deltax, ensemble)
    for file in files[1:]:
        print(file)
        df_station_add = glofas_extract_file("%s/%s" % (directory, file), st_lat, st_lon, deltax, ensemble)
        df_station = pd.concat([df_station, df_station_add], axis=0, sort=False)
    return(df_station)

# reading GloFAS GRIB file
ensemble = list(range(1,11))
deltax=0.05
input_dir = 'c:/Users/BOttow/Rode Kruis/510 - Data preparedness and IBF - [CTRY] Uganda/GIS Data/GloFAS'
output_dir = 'c:/Users/BOttow/Documents/IBF-system/trigger-model-development/flood/skill-assessment/download_glofas/output'
files = os.listdir(input_dir)
r = re.compile('.*\.grib$')
filtered_files = [ s for s in files if r.match(s) ]

station_file = 'c:/Users/BOttow/Rode Kruis/510 - Data preparedness and IBF - [CTRY] Uganda/IBF Dashboard data/rp_glofas_station_uga_v2.csv' 
stations = pd.read_csv(station_file)


for i in list(stations.index)[1:]:
    print(stations['ID'][i])
    st_lat = stations['lat'][i]
    st_lon = stations['lon'][i]
    df_station = glofas_extract_station(input_dir, filtered_files, st_lat, st_lon, deltax, ensemble)
    df_station.to_csv("%s/glofas_hindcast_5dayLT_%s.csv" % (output_dir, stations['ID'][i]), index = False)

