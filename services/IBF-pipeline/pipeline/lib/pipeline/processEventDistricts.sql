-- NOTE: Save districts to event. Each day check if there are new districts. Never delete any districts that are not triggered any more.
CREATE table if not exists "IBF-pipeline-output".event_place_code (
	"eventPlaceCodeId" uuid NOT NULL DEFAULT uuid_generate_v4(),
	"placeCode" varchar NOT NULL,
	"startDate" timestamp NOT NULL,
	"populationAffected" float8 not null,
	"endDate" timestamp NULL,
	"manualClosedDate" timestamp NULL,
	"activeTrigger" bool NOT NULL DEFAULT true,
	closed bool NOT NULL DEFAULT false,
	CONSTRAINT "CHK_8e945c9a741036988f4bf6ee2e" CHECK (("startDate" < "endDate")),
	CONSTRAINT "PK_a44cfd74b39d84fa9a9c42ef302" PRIMARY KEY ("eventPlaceCodeId")
);

-- First set all events as inactive
update
	"IBF-pipeline-output".event_place_code
set
	"activeTrigger" = false;

-- Second, update (potentially) updated population-affected figures for existing pcodes and set "activeTrigger" events "activeTrigger" again
update
	"IBF-pipeline-output".event_place_code
set
	"endDate" = (now() + interval '7 DAY')::date, 
	"activeTrigger" = true,
	"populationAffected" = subquery.population_affected
from
	(
	select
		districtsToday.*
	from
		(
		select pcode,
			max(t1.population_affected) as population_affected
		from
			"IBF-pipeline-output".dashboard_calculated_affected t1
		where
			t1.population_affected  > 0
			and t1.date = current_date
		group by pcode
		) districtsToday
	left join "IBF-pipeline-output".event_place_code eventPcodeExisting on
		districtsToday.pcode = eventPcodeExisting."placeCode"
	where
		eventPcodeExisting."placeCode" is not null
		and eventPcodeExisting.closed is false ) subquery
where
	event_place_code."placeCode" = subquery.pcode
	and event_place_code.closed = false 
;



-- Third: add new districts (either within existing event, or completely new event)
insert into "IBF-pipeline-output".event_place_code("placeCode",  "startDate", "endDate","populationAffected")
select  districtsToday.*
from (
	select t1.pcode 
		,now()::date as "startDate"
		,(now() + interval '7 DAY')::date as "endDate" 		
		,max(population_affected) as population_affected
    from "IBF-pipeline-output".dashboard_calculated_affected t1
	where t1.population_affected > 0
		and t1.date = current_date
	GROUP BY t1.pcode, "startDate", "endDate"
) districtsToday
left join "IBF-pipeline-output".event_place_code districtsExisting
	on districtsToday.pcode = districtsExisting."placeCode"
	and districtsExisting.closed = false
where districtsExisting."placeCode" is null
;
--select * from "IBF-pipeline-output".event_place_code

-- Lastly Close events older than 7 leadTimeValue
update
	"IBF-pipeline-output".event_place_code
set
	closed = true
where 
	"endDate" < now()::date
	;