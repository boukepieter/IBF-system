-- NOTE: Save districts to event. Each day check if there are new districts. Never delete any districts that are not triggered any more.
-- NOTE: this table is created with TypeORM from event-place-code.entity.ts

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