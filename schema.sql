--
-- Name: scorecard_aggregates(character varying, character varying, bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION scorecard_aggregates(start_date character varying, finish_date character varying, user_id bigint) RETURNS TABLE(dimension_merch_type_or_agency_name_ text, dimension_type_ text, route_planned_ bigint, route_fact_ bigint, route_ratio_ text, loca_planned_ bigint, loca_fact_ bigint, loca_ratio_ text, planned_count_ bigint, fact_count_ bigint, unplanned_count_ bigint, all_visits_ bigint, visits_ratio_ text, fact_sale_point_time_hrs_ text, fact_travel_time_hrs_ text, fact_total_time_hrs_ text, planned_sale_point_time_hrs_ text, planned_travel_time_hrs_ text, planned_total_time_hrs_ text, started_morning_ratio_ text, finished_evening_ratio_ text, started_morning_ bigint, finished_evening_ bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN

	SET LC_NUMERIC TO 'en_US.UTF-8';

  RETURN QUERY

WITH stats_totals  AS (

SELECT

	dim,
	dimension_type,
	route_planned, route_fact, route_planned_daily, route_fact_daily, route_fact_today,
	loca_planned, loca_fact,

	planned_checkin, fact_checkin, unplanned_checkin,
	fact_sale_point_time_hrs, fact_travel_time_hrs,
	planned_sale_point_time_hrs, planned_travel_time_hrs,
	started_morning, finished_evening

FROM
(
WITH stats_agg  AS (

SELECT

region_code, merch_type, agency_name,

SUM(route_planned)::INT route_planned,
SUM(route_planned_daily)::INT route_planned_daily,
SUM(route_fact_daily)::INT route_fact_daily,
SUM(route_fact)::INT route_fact,
SUM(route_fact_today)::INT route_fact_today,

SUM(loca_planned)::INT  loca_planned,
SUM(loca_fact)::INT loca_fact,

SUM(planned_checkin)::INT planned_checkin,
SUM(fact_checkin)::INT fact_checkin,
SUM(unplanned_checkin)::INT unplanned_checkin,

SUM(fact_sale_point_time)::NUMERIC fact_sale_point_time_hrs,
SUM(fact_travel_time)::NUMERIC     fact_travel_time_hrs,

SUM(planned_sale_point_time)::NUMERIC planned_sale_point_time_hrs,
SUM(planned_travel_time)::NUMERIC     planned_travel_time_hrs,

SUM(started_morning)::INT started_morning,
SUM(finished_evening)::INT finished_evening

FROM
(
	WITH stats AS (

		SELECT
			region_code,
			merchendising_type merch_type,
			agency_name,
			COALESCE(NULLIF(dm.route_id, 'заменен мерчандайзер или нет в АП'), uid::text) route_id,
			(location_id) 	 loca_id,
			/*CASE
				WHEN ((created_at::DATE = finished_at::DATE) OR
						   finished_at IS NULL)
				THEN (COALESCE(NULLIF(planned_checkins,2),1))
				ELSE 0
			END*/
			(COALESCE(NULLIF(planned_checkins,2),1))
				planned_checkin,
			(COALESCE(fact_checkins,0)) fact_checkin,
			(COALESCE(unplanned_checkins,0)) unplanned_checkin,

			(COALESCE(fact_sale_point_time,0))/60.0
				fact_sale_point_time,
			CASE
				WHEN merchendising_type='stationary' THEN 0
				ELSE (COALESCE(fact_travel_time,0))/60.0
			END
				fact_travel_time,
			(COALESCE(sale_point_time,0))/60.0
				planned_sale_point_time,
			CASE
				WHEN merchendising_type='stationary' THEN 0
				ELSE (COALESCE(travel_time,0))/60.0
			END
				planned_travel_time,

			(started_morning)   started_morning,
			(finished_evening) finished_evening,
      checkin_lite,
			dm.started_date::DATE thedate

		FROM scorecard_mart dm
		WHERE
		CASE
			WHEN user_id=1608 THEN executive_id in (104,457)
			ELSE user_id IN (supervisor_id, teamlead_id, regional_manager_id, manager_id, executive_id)
		END
		AND
		(
		 (started_date     BETWEEN start_date::DATE AND finish_date::DATE AND created_at IS NULL) OR
		 (created_at::DATE BETWEEN start_date::DATE AND finish_date::DATE)
		)
)

SELECT
       	region_code, merch_type, agency_name, thedate,
       	0
             route_planned,
       	0
             loca_planned,
       	0
             route_fact,
				(count(distinct route_id) FILTER(WHERE planned_checkin in (1,2)))
						route_planned_daily,
				(count(distinct route_id) FILTER(WHERE fact_checkin=1 OR unplanned_checkin=1))
						route_fact_daily,
				0
						route_fact_today,
       	0
             loca_fact,
       	0
             route_unplanned,
       	0
             loca_unplanned,

       	COALESCE(SUM(COALESCE(planned_checkin,0)) 	FILTER(WHERE planned_checkin in (1,2)),0)
             planned_checkin,
       	COALESCE(SUM(COALESCE(fact_checkin,0)) 			FILTER(WHERE fact_checkin=1),0)
             fact_checkin,
       	COALESCE(SUM(COALESCE(unplanned_checkin,0)) FILTER(WHERE unplanned_checkin=1),0)
             unplanned_checkin,

           COALESCE((SUM(fact_sale_point_time)    FILTER(WHERE fact_checkin=1 OR unplanned_checkin=1)),0)
             fact_sale_point_time,
           COALESCE((SUM(fact_travel_time)        FILTER(WHERE fact_checkin=1 OR unplanned_checkin=1)),0)
             fact_travel_time,

           COALESCE((SUM(planned_sale_point_time) FILTER(WHERE planned_checkin in (1,2) )),0)
             planned_sale_point_time,
           COALESCE((SUM(planned_travel_time)     FILTER(WHERE planned_checkin in (1,2) )),0)
             planned_travel_time,

       		SUM(started_morning)
             started_morning,
       		SUM(finished_evening)
             finished_evening

       	FROM stats
       	GROUP BY region_code, merch_type, agency_name, thedate

	UNION ALL

	SELECT
       	region_code, merch_type, agency_name, null thedate,
       	(count(distinct route_id) FILTER(WHERE planned_checkin in (1,2) ))
             route_planned,
       	(count(distinct loca_id)  FILTER(WHERE planned_checkin in (1,2) ))
             loca_planned,
       	(count(distinct route_id) FILTER(WHERE fact_checkin=1 OR unplanned_checkin=1))
             route_fact,
			  0
			 			 route_planned_daily,
			  0
			 			 route_fact_daily,
       	(count(distinct route_id) FILTER(WHERE fact_checkin=1 OR unplanned_checkin=1 OR checkin_lite=1))
             route_fact_today,
       	(count(distinct loca_id)  FILTER(WHERE fact_checkin=1 OR unplanned_checkin=1))
             loca_fact,
       	(COUNT(DISTINCT route_id) FILTER(WHERE unplanned_checkin=1))
             route_unplanned,
       	(COUNT(DISTINCT loca_id)  FILTER(WHERE unplanned_checkin=1))
             loca_unplanned,

       	0
             planned_checkin,
       	0
             fact_checkin,
       	0
             unplanned_checkin,

				0
             fact_sale_point_time,
        0
             fact_travel_time,

        0
             planned_sale_point_time,
        0
             planned_travel_time,

       	0
             started_morning,
       	0
             finished_evening

       	FROM stats
       	GROUP BY region_code, merch_type, agency_name
)DATA
GROUP BY region_code, merch_type, agency_name
)

SELECT
region_code,
merch_type dim,
'merch_type' dimension_type,

SUM(route_planned)
		route_planned,
SUM(route_fact)::BIGINT
		route_fact,
SUM(route_planned_daily)::BIGINT
		route_planned_daily,
SUM(route_fact_daily)::BIGINT
		route_fact_daily,
SUM(route_fact_today)::BIGINT
		route_fact_today,

SUM(loca_planned)
		loca_planned,
SUM(loca_fact)
		loca_fact,

SUM(planned_checkin)
		planned_checkin,
SUM(fact_checkin)
		fact_checkin,
COALESCE(SUM(unplanned_checkin),0)
		unplanned_checkin,

SUM(fact_sale_point_time_hrs)
		fact_sale_point_time_hrs,
SUM(fact_travel_time_hrs)
		fact_travel_time_hrs,

SUM(planned_sale_point_time_hrs)
		planned_sale_point_time_hrs,
SUM(planned_travel_time_hrs)
		planned_travel_time_hrs,

SUM(started_morning)::BIGINT
		started_morning,
SUM(finished_evening)::BIGINT
		finished_evening



FROM stats_agg
GROUP BY region_code, merch_type

UNION ALL

SELECT
region_code,
agency_name dim,
'agency_name' dimension_type,

SUM(route_planned)
		route_planned,
SUM(route_fact)::BIGINT
		route_fact,
SUM(route_planned_daily)::BIGINT
		route_planned_daily,
SUM(route_fact_daily)::BIGINT
		route_fact_daily,
SUM(route_fact_today)::BIGINT
		route_fact_today,

SUM(loca_planned)
		loca_planned,
SUM(loca_fact)
		loca_fact,

SUM(planned_checkin)
		planned_checkin,
SUM(fact_checkin)
		fact_checkin,
COALESCE(SUM(unplanned_checkin),0)
		unplanned_checkin,

SUM(fact_sale_point_time_hrs)
		fact_sale_point_time_hrs,
SUM(fact_travel_time_hrs)
		fact_travel_time_hrs,

SUM(planned_sale_point_time_hrs)
		planned_sale_point_time_hrs,
SUM(planned_travel_time_hrs)
		planned_travel_time_hrs,

SUM(started_morning)::BIGINT
		started_morning,
SUM(finished_evening)::BIGINT
		finished_evening



FROM stats_agg
GROUP BY region_code, agency_name

)data

ORDER BY
CASE
	WHEN region_code =	'Москва' 	THEN '1'
	WHEN region_code in ('СПБ-NW','Северо-Запад') 	THEN '2'
	WHEN region_code in ('Центр','Центральная Россия') 	THEN '3'
	WHEN region_code in ('Волга','Поволжье')	THEN '4'
	WHEN region_code =	'Юг' 	THEN '5'
	WHEN region_code =	'Урал' 	THEN '6'
	WHEN region_code =	'Сибирь' 	THEN '7'
	WHEN region_code =	'---' 	THEN '99'
	ELSE region_code
END,
CASE
	WHEN dim='ttl' 					THEN 0
	WHEN dim='visit' 				THEN 1
	WHEN dim='stationary' 	THEN 2
	WHEN dim='shared' 			THEN 3
	WHEN dim='--' 					THEN 4
	WHEN dim='-' 						THEN 99
	ELSE 4
END

)

SELECT 'ttl' dim, 'ttl' dimension_type,

SUM(route_planned)::BIGINT
		route_planned,
SUM(route_fact_today)::BIGINT
		route_fact,
TO_CHAR(SUM(route_fact)*100.0/GREATEST(1,SUM(route_planned)), 'FM999999999990D09')
		route_ratio,

SUM(loca_planned)::BIGINT
		loca_planned,
SUM(loca_fact)::BIGINT
		loca_fact,
TO_CHAR(SUM(loca_fact)*100.0/GREATEST(1,SUM(loca_planned)), 'FM999999999990D09')
		loca_ratio,

SUM(planned_checkin)::BIGINT
		planned_checkin,
SUM(fact_checkin)::BIGINT
		fact_checkin,
COALESCE(SUM(unplanned_checkin),0)::BIGINT
		unplanned_checkin,
(SUM(fact_checkin) + SUM(unplanned_checkin))::BIGINT all_visits,
TO_CHAR(((SUM(fact_checkin) + COALESCE(SUM(unplanned_checkin),0))*100.0/GREATEST(1,SUM(planned_checkin))), 'FM999999999990D09')
		visits_ratio,

TO_CHAR(SUM(fact_sale_point_time_hrs::NUMERIC)/GREATEST(1,(SUM(route_fact_daily))::INT), 'FM999999999990D099999999')
		fact_sale_point_time_hrs,
TO_CHAR(SUM(fact_travel_time_hrs::NUMERIC)/GREATEST(1,(SUM(route_fact_daily))::INT), 'FM999999999990D099999999')
		fact_travel_time_hrs,
TO_CHAR((SUM(fact_sale_point_time_hrs)+SUM(fact_travel_time_hrs))/GREATEST(1,(SUM(route_fact_daily))::INT), 'FM999999999990D099999999')
		total_time_hrs,

TO_CHAR(SUM(planned_sale_point_time_hrs::NUMERIC)/GREATEST(1,SUM(route_planned_daily)), 'FM999999999990D099999999')
		planned_sale_point_time_hrs,
TO_CHAR(SUM(planned_travel_time_hrs::NUMERIC )/GREATEST(1,SUM(route_planned_daily)), 'FM999999999990D099999999')
		planned_travel_time_hrs,
TO_CHAR((SUM(planned_sale_point_time_hrs)+SUM(planned_travel_time_hrs))/GREATEST(1,SUM(route_planned_daily)), 'FM999999999990D099999999')
		planned_total_time_hrs,

TO_CHAR(SUM(started_morning)::INT*100.0/GREATEST(1, SUM(route_fact_daily)::INT), 'FM999999999990D09')
		started_morning_ratio,
TO_CHAR(SUM(finished_evening)::INT*100.0/GREATEST(1,SUM(route_fact_daily)::INT), 'FM999999999990D09')
		finished_evening_ratio,

SUM(started_morning)::BIGINT  started_morning,
SUM(finished_evening)::BIGINT finished_evening

FROM stats_totals
WHERE dimension_type='merch_type'

UNION ALL

SELECT dim, 'merch_type' dimension_type,

SUM(route_planned)::BIGINT
		route_planned,
SUM(route_fact_today)::BIGINT
		route_fact,
TO_CHAR(SUM(route_fact)*100.0/GREATEST(1,SUM(route_planned)), 'FM999999999990D09')
		route_ratio,

SUM(loca_planned)::BIGINT
		loca_planned,
SUM(loca_fact)::BIGINT
		loca_fact,
TO_CHAR(SUM(loca_fact)*100.0/GREATEST(1,SUM(loca_planned)), 'FM999999999990D09')
		loca_ratio,

SUM(planned_checkin)::BIGINT
		planned_checkin,
SUM(fact_checkin)::BIGINT
		fact_checkin,
COALESCE(SUM(unplanned_checkin),0)::BIGINT
		unplanned_checkin,
(SUM(fact_checkin) + SUM(unplanned_checkin))::BIGINT all_visits,
TO_CHAR(((SUM(fact_checkin) + COALESCE(SUM(unplanned_checkin),0))*100.0/GREATEST(1,SUM(planned_checkin))), 'FM999999999990D09')
		visits_ratio,

TO_CHAR(SUM(fact_sale_point_time_hrs::NUMERIC)/GREATEST(1,(SUM(route_fact_daily))::INT), 'FM999999999990D099999999')
		fact_sale_point_time_hrs,
TO_CHAR(SUM(fact_travel_time_hrs::NUMERIC)/GREATEST(1,(SUM(route_fact_daily))::INT), 'FM999999999990D099999999')
		fact_travel_time_hrs,
TO_CHAR((SUM(fact_sale_point_time_hrs)+SUM(fact_travel_time_hrs))/GREATEST(1,(SUM(route_fact_daily))::INT), 'FM999999999990D099999999')
		total_time_hrs,

TO_CHAR(SUM(planned_sale_point_time_hrs::NUMERIC)/GREATEST(1,SUM(route_planned_daily)), 'FM999999999990D099999999')
		planned_sale_point_time_hrs,
TO_CHAR(SUM(planned_travel_time_hrs::NUMERIC )/GREATEST(1,SUM(route_planned_daily)), 'FM999999999990D099999999')
		planned_travel_time_hrs,
TO_CHAR((SUM(planned_sale_point_time_hrs)+SUM(planned_travel_time_hrs))/GREATEST(1,SUM(route_planned_daily)), 'FM999999999990D099999999')
		planned_total_time_hrs,

TO_CHAR(SUM(started_morning)::INT*100.0/GREATEST(1, SUM(route_fact_daily)::INT), 'FM999999999990D09')
		started_morning_ratio,
TO_CHAR(SUM(finished_evening)::INT*100.0/GREATEST(1,SUM(route_fact_daily)::INT), 'FM999999999990D09')
		finished_evening_ratio,

SUM(started_morning)::BIGINT  started_morning,
SUM(finished_evening)::BIGINT finished_evening

FROM stats_totals
WHERE dimension_type='merch_type'
GROUP BY dim

UNION ALL

SELECT dim, 'agency_name' dimension_type,

SUM(route_planned)::BIGINT
		route_planned,
SUM(route_fact_today)::BIGINT
		route_fact,
TO_CHAR(SUM(route_fact)*100.0/GREATEST(1,SUM(route_planned)), 'FM999999999990D09')
		route_ratio,

SUM(loca_planned)::BIGINT
		loca_planned,
SUM(loca_fact)::BIGINT
		loca_fact,
TO_CHAR(SUM(loca_fact)*100.0/GREATEST(1,SUM(loca_planned)), 'FM999999999990D09')
		loca_ratio,

SUM(planned_checkin)::BIGINT
		planned_checkin,
SUM(fact_checkin)::BIGINT
		fact_checkin,
COALESCE(SUM(unplanned_checkin),0)::BIGINT
		unplanned_checkin,
(SUM(fact_checkin) + SUM(unplanned_checkin))::BIGINT all_visits,
TO_CHAR(((SUM(fact_checkin) + COALESCE(SUM(unplanned_checkin),0))*100.0/GREATEST(1,SUM(planned_checkin))), 'FM999999999990D09')
		visits_ratio,

TO_CHAR(SUM(fact_sale_point_time_hrs::NUMERIC)/GREATEST(1,(SUM(route_fact_daily))::INT), 'FM999999999990D099999999')
		fact_sale_point_time_hrs,
TO_CHAR(SUM(fact_travel_time_hrs::NUMERIC)/GREATEST(1,(SUM(route_fact_daily))::INT), 'FM999999999990D099999999')
		fact_travel_time_hrs,
TO_CHAR((SUM(fact_sale_point_time_hrs)+SUM(fact_travel_time_hrs))/GREATEST(1,(SUM(route_fact_daily))::INT), 'FM999999999990D099999999')
		total_time_hrs,

TO_CHAR(SUM(planned_sale_point_time_hrs::NUMERIC)/GREATEST(1,SUM(route_planned_daily)), 'FM999999999990D099999999')
		planned_sale_point_time_hrs,
TO_CHAR(SUM(planned_travel_time_hrs::NUMERIC )/GREATEST(1,SUM(route_planned_daily)), 'FM999999999990D099999999')
		planned_travel_time_hrs,
TO_CHAR((SUM(planned_sale_point_time_hrs)+SUM(planned_travel_time_hrs))/GREATEST(1,SUM(route_planned_daily)), 'FM999999999990D099999999')
		planned_total_time_hrs,

TO_CHAR(SUM(started_morning)::INT*100.0/GREATEST(1, SUM(route_fact_daily)::INT), 'FM999999999990D09')
		started_morning_ratio,
TO_CHAR(SUM(finished_evening)::INT*100.0/GREATEST(1,SUM(route_fact_daily)::INT), 'FM999999999990D09')
		finished_evening_ratio,

SUM(started_morning)::BIGINT  started_morning,
SUM(finished_evening)::BIGINT finished_evening

FROM stats_totals
WHERE dimension_type='agency_name'
GROUP BY dim;

END;
$$;
