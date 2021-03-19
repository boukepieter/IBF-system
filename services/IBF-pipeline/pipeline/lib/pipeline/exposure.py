import rasterio
import rasterio.mask
import rasterio.features
import rasterio.warp
from rasterio.features import shapes
import fiona
import numpy as np
import pandas as pd
from pandas import DataFrame
import json

from lib.logging.logglySetup import logger
from settings import *
import os

class Exposure:

    """Class used to calculate the exposure per exposure type"""
    
    def __init__(self, leadTimeLabel, country_code, admin_area_gdf, district_mapping = None, district_cols = None):
        self.leadTimeLabel = leadTimeLabel
        self.country_code = country_code
        if SETTINGS[country_code]['model'] == 'glofas':
            self.disasterExtentRaster = GEOSERVER_OUTPUT + '0/flood_extents/flood_extent_'+ leadTimeLabel + '_' + country_code + '.tif'
        elif SETTINGS[country_code]['model'] == 'rainfall':
            self.disasterExtentRaster = GEOSERVER_OUTPUT + '0/rainfall_extents/rain_rp_'+ leadTimeLabel + '_' + country_code + '.tif'
        self.selectionValue = 0.9
        self.outputPath = PIPELINE_OUTPUT + "out.tif"
        self.district_mapping = district_mapping
        self.district_cols = district_cols
        self.ADMIN_AREA_GDF = admin_area_gdf
        self.ADMIN_AREA_GDF_TMP_PATH = PIPELINE_OUTPUT+"admin-areas_TMP.shp"
        self.EXPOSURE_DATA_SOURCES = SETTINGS[country_code]['EXPOSURE_DATA_SOURCES']
        self.statsPath = PIPELINE_OUTPUT + 'calculated_affected/affected_' + leadTimeLabel + '_' + country_code + '.json'
        self.stats = []

    def callAllExposure(self):
        logger.info('Started calculating affected of %s', self.disasterExtentRaster)

        for indicator, values in self.EXPOSURE_DATA_SOURCES.items():
            print('indicator: ', indicator)
            self.inputRaster = GEOSERVER_INPUT + values['source'] + ".tif"
            self.outputRaster = GEOSERVER_OUTPUT + "0/" + values['source'] + self.leadTimeLabel

            self.calcAffected(self.disasterExtentRaster, indicator, values['rasterValue'])


        with open(self.statsPath, 'w') as fp:
            json.dump(self.stats, fp)
            logger.info("Saved stats for %s", self.statsPath)

    def calcAffected(self, disasterExtentRaster, indicator, rasterValue):
        disasterExtentShapes = self.loadTiffAsShapes(disasterExtentRaster)
        if disasterExtentShapes != []:
            try:
                affectedImage, affectedMeta = self.clipTiffWithShapes(self.inputRaster, disasterExtentShapes)
                with rasterio.open(self.outputRaster, "w", **affectedMeta) as dest:
                    dest.write(affectedImage)
            except ValueError:
                print('Rasters do not overlap')
        logger.info("Wrote to " + self.outputRaster)
        self.ADMIN_AREA_GDF.to_file(self.ADMIN_AREA_GDF_TMP_PATH)
        stats = self.calcStatsPerAdmin(indicator, disasterExtentShapes, rasterValue)
        
        for item in stats:
            self.stats.append(item)

                 
    def calcStatsPerAdmin(self, indicator, disasterExtentShapes, rasterValue):
        if SETTINGS[self.country_code]['model'] == 'glofas':
            #Load trigger_data per station
            path = PIPELINE_DATA+'output/triggers_rp_per_station/triggers_rp_' + self.leadTimeLabel + '_' + self.country_code + '.json'
            df_triggers = pd.read_json(path, orient='records')
            df_triggers = df_triggers.set_index("station_code", drop=False)
            #Load assigned station per district
            df_district_mapping = DataFrame(self.district_mapping)
            df_district_mapping.columns = self.district_cols
            df_district_mapping = df_district_mapping.set_index("pcode", drop=False)

        stats = []
        with fiona.open(self.ADMIN_AREA_GDF_TMP_PATH, "r") as shapefile:

            # Clip affected raster per area
            for area in shapefile:
                if disasterExtentShapes != []: 
                    try: 
                        outImage, outMeta = self.clipTiffWithShapes(self.outputRaster, [area["geometry"]] )
                        
                        # Write clipped raster to tempfile to calculate raster stats
                        with rasterio.open(self.outputPath, "w", **outMeta) as dest:
                            dest.write(outImage)
                            
                        statsDistrict = self.calculateRasterStats(indicator,  str(area['properties']['pcode']), self.outputPath, rasterValue)

                        # Overwrite non-triggered areas with positive exposure (due to rounding errors) to 0
                        if SETTINGS[self.country_code]['model'] == 'glofas':
                            if self.checkIfTriggeredArea(df_triggers,df_district_mapping,str(area['properties']['pcode'])) == 0:
                                statsDistrict = {'source': indicator, 'sum': 0, 'district': str(area['properties']['pcode'])}
                        if self.country_code == 'EGY':
                            if 'EG' not in str(area['properties']['pcode']):
                                statsDistrict = {'source': indicator, 'sum': 0, 'district': str(area['properties']['pcode'])}
                    except (ValueError, rasterio.errors.RasterioIOError):
                            # If there is no disaster in the district set  the stats to 0
                        statsDistrict = {'source': indicator, 'sum': 0, 'district': str(area['properties']['pcode'])}
                else: 
                    statsDistrict = {'source': indicator, 'sum': '--', 'district': str(area['properties']['pcode'])}        
                stats.append(statsDistrict)
        os.remove(self.ADMIN_AREA_GDF_TMP_PATH)
        return stats    

    def checkIfTriggeredArea(self, df_triggers, df_district_mapping, pcode):
        df_station_code = df_district_mapping[df_district_mapping['pcode'] == pcode]
        if df_station_code.empty:
            return 0
        station_code = df_station_code['station_code'][0]
        if station_code == 'no_station':
            return 0
        df_trigger = df_triggers[df_triggers['station_code'] == station_code]
        if df_trigger.empty:
            return 0
        trigger = df_trigger['fc_trigger'][0]
        return trigger

    def calculateRasterStats(self, indicator, district, outFileAffected, rasterValue):
        raster = rasterio.open(outFileAffected)   
        stats = []

        array = raster.read( masked=True)
        band = array[0]
        theSum = band.sum() * rasterValue
        stats.append({
            'source': indicator,
            'sum': str(theSum),
            'district': district
            })
        return stats[0]



    def loadTiffAsShapes(self, tiffLocaction):
        allgeom = []
        with rasterio.open(tiffLocaction) as dataset:
            # Read the dataset's valid data mask as a ndarray.
            image = dataset.read(1).astype(np.float32)
            mask = dataset.dataset_mask()
            theShapes = shapes(image, mask=mask, transform=dataset.transform)
            
            # Extract feature shapes and values from the array.
            for geom, val in theShapes:
                if val >= self.selectionValue:              
                    # Transform shapes from the dataset's own coordinate
                    # reference system to CRS84 (EPSG:4326).
                    geom = rasterio.warp.transform_geom(
                        dataset.crs, 'EPSG:4326', geom, precision=6)
                    # Append everything to one geojson
                    
                    allgeom.append(geom)   
        return allgeom



    def clipTiffWithShapes(self, tiffLocaction, shapes):
        with rasterio.open(tiffLocaction) as src:
            outImage, out_transform = rasterio.mask.mask(src, shapes, crop=True)
            outMeta = src.meta.copy()

        outMeta.update({"driver": "GTiff",
                    "height": outImage.shape[1],
                    "width": outImage.shape[2],
                    "transform": out_transform})

        return outImage, outMeta