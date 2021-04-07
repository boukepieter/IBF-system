--This script is not connected explicitly to the rest of the repository
--These views/functions are stored in Postgres and called from
--They are kept explicitly here in the repository for documentation

DROP TABLE IF EXISTS "IBF-static-input".dashboard_glofas_stations cascade;
create table "IBF-static-input".dashboard_glofas_stations as
select "countryCode" as country_code
	, "stationCode" as station_code
	, "stationName" as station_name
	, "triggerLevel" as trigger_level
	, "threshold2Year" as "2yr_threshold"
	, "threshold5Year" as "5yr_threshold"
	, "threshold10Year" as "10yr_threshold"
	, "threshold20Year" as "20yr_threshold"
	, st_astext(geom) as geom
	, lat
	, lon
from "IBF-app"."glofasStation"
;
--select * from "IBF-static-input".dashboard_glofas_stations

DROP TABLE IF EXISTS "IBF-static-input".waterstation_per_district;
create table "IBF-static-input".waterstation_per_district as
select "countryCode" as country_code
		,"name"
		,pcode
		,"glofasStation" as station_code
from "IBF-app"."adminArea" aa
;
--select * from "IBF-static-input".waterstation_per_district

DROP TABLE IF EXISTS "IBF-static-input".dashboard_redcross_branches;
create table "IBF-static-input".dashboard_redcross_branches as
select "countryCode"
		,"name"
		,"numberOfVolunteers"
		,"contactPerson"
		,"contactAddress"
		,"contactNumber"
		, ST_AsGeoJSON(st_astext(geom))::json as geom
from "IBF-app"."redcrossBranch"
;
--select * from "IBF-static-input".dashboard_redcross_branches

--TO DO: transform to generic row-to-column pivot (but not worth it before completely moving all sql to typescript)
drop table if exists "IBF-static-input".dashboard_admin_area_data;
create table "IBF-static-input".dashboard_admin_area_data as
select aa.pcode
		,max(case when key = 'population_over65' then value end) as population_over65
		,max(case when key = 'female_head_hh' then value end) as female_head_hh
		,max(case when key = 'population_u8' then value end) as population_u8
		,max(case when key = 'poverty_incidence' then value end) as poverty_incidence
		,max(case when key = 'roof_type' then value end) as roof_type
		,max(case when key = 'wall_type' then value end) as wall_type
		,max(case when key = 'Weighted Vulnerability Index' then value end) as vulnerability_index
		,max(case when key = 'covid_risk' then value end) as covid_risk
from "IBF-app"."adminArea" aa
left join "IBF-app"."adminAreaData" aad
	on aa.pcode = aad."placeCode"
group by 1
;
--select * from "IBF-static-input".dashboard_admin_area_data

--create API view for Glofas stations
drop view if exists "IBF-API"."Glofas_stations";
create or replace view "IBF-API"."Glofas_stations" as
select dfps.country_code
		,dfps.lead_time
		,dgsv.station_code
		,dgsv.station_name
		,dgsv.trigger_level
		,dgsv.geom
	  , dfps.fc
      , dfps.fc_trigger
      , dfps.fc_perc
      , dfps.fc_prob
from (
	select "countryCode" as country_code
		,"stationCode" as station_code
		,"stationName" as station_name
		,"triggerLevel" as trigger_level
		,ST_AsGeoJSON(geom)::json As geom
	from "IBF-app"."glofasStation" gs
	) dgsv
left join "IBF-pipeline-output".dashboard_forecast_per_station dfps on dgsv.station_code = dfps.station_code and dgsv.country_code = dfps.country_code
;
--select * from "IBF-API"."Glofas_stations" where lead_time = '3-day' and country_code = 'ZMB'

drop view if exists "IBF-API"."Trigger_per_lead_time";
create or replace view "IBF-API"."Trigger_per_lead_time" as
select *
from "IBF-pipeline-output".dashboard_triggers_per_day
;
--select * from "IBF-API"."Trigger_per_lead_time"

drop view if exists "IBF-API"."Admin_area_data2" cascade;
create or replace view "IBF-API"."Admin_area_data2" as
select geo.pcode as pcode_level2
	,geo."name"
	,geo."pcodeParent" as pcode_level1
	,ST_AsGeoJSON(geo.geom)::json As geom
	,"countryCode" as country_code
	,d2.pcode, "date", lead_time, fc, fc_trigger, fc_rp, fc_perc, fc_prob, population_affected, indicators
from "IBF-app"."adminArea" geo
left join "IBF-pipeline-output".data_adm2 d2 on geo.pcode = d2.pcode
where "adminLevel" = 2
;
--select * from "IBF-API"."Admin_area_data2" where country_code = 'UGA'

drop view if exists "IBF-API"."Admin_area_data1" cascade;
create or replace view "IBF-API"."Admin_area_data1" as
select geo.pcode as pcode_level1
	,geo."name"
	,geo."pcodeParent" as pcode_level0
	,ST_AsGeoJSON(geo.geom)::json As geom
	,"countryCode" as country_code
--	,d2.*
	,d2.pcode, "date", lead_time, fc, fc_trigger, fc_rp, fc_perc, fc_prob, population_affected, indicators
from "IBF-app"."adminArea" geo
left join "IBF-pipeline-output".data_adm2 d2 on geo.pcode = d2.pcode
where "adminLevel" = 1
;
--select * from "IBF-API"."Admin_area_data1" where country_code = 'EGY'

drop view if exists "IBF-API"."Matrix_aggregates2";
create or replace view "IBF-API"."Matrix_aggregates2" as
select country_code
	,lead_time
	,sum(population_affected) as population_affected
from "IBF-API"."Admin_area_data2"
where country_code is not null
group by 1,2
;
--select * from "IBF-API"."Matrix_aggregates2"

drop view if exists "IBF-API"."Matrix_aggregates1";
create or replace view "IBF-API"."Matrix_aggregates1" as
select country_code
	,lead_time
	,sum(population_affected) as population_affected
from "IBF-API"."Admin_area_data1"
where country_code is not null
group by 1,2
;
--select * from "IBF-API"."Matrix_aggregates1"

