-- schema.sql frags #2

--
-- Name: scorecard_checkins; Type: MATERIALIZED VIEW; Schema: public; Owner: -; Tablespace: 
--

CREATE MATERIALIZED VIEW scorecard_checkins AS
 SELECT scorecard_checkins.*
   FROM ( SELECT row_number() OVER () AS scid,
            data.checkin_id,
            users.id AS user_id,
            locations.city,
            signboards.name AS signboard_name,
            companies.name AS company_name,
            location_types.name AS location_types_name,
            location_categories.name AS location_category_name,
            locations.address,
            locations.id AS location_id,
            data.started_date,
                CASE
                    WHEN (data.plan_created_today = 1) THEN 2
                    WHEN (((data.checkin_plan_item_id IS NOT NULL) OR (data.plan_item_id IS NOT NULL)) AND (((data.created_at)::date = data.started_date) OR (data.created_at IS NULL))) THEN 1
                    ELSE 0
                END AS planned_checkins,
                CASE
                    WHEN (((data.checkin_plan_item_id IS NOT NULL) OR (data.plan_item_id IS NOT NULL)) AND (data.checkin_id IS NOT NULL)) THEN 1
                    ELSE 0
                END AS fact_checkins,
                CASE
                    WHEN ((data.checkin_plan_item_id IS NULL) AND (data.checkin_id IS NOT NULL)) THEN 1
                    ELSE 0
                END AS unplanned_checkins,
            organizations.id AS organization_id,
            COALESCE(inspector_locations.planned_move_time, organizations.travel_time) AS travel_time,
                CASE
                    WHEN (data.started_at IS NOT NULL) THEN GREATEST(((date_part('epoch'::text, (data.started_at - lead(data.finished_at) OVER previous_checkin)) / (60)::double precision))::integer, 0)
                    ELSE NULL::integer
                END AS fact_travel_time,
                CASE
                    WHEN ((data.checkin_plan_item_id IS NULL) AND (data.checkin_id IS NOT NULL)) THEN 0
                    ELSE COALESCE(inspector_locations.planned_time, data.planned_time, locations.planned_visit_time, location_organizations."time")
                END AS sale_point_time,
            (((date_part('epoch'::text, (data.finished_at - data.started_at)) / (60)::double precision))::integer + COALESCE(data.first_visit_time, 0)) AS fact_sale_point_time,
            min(data.started_at) OVER (PARTITION BY (data.started_at)::date, data.user_id) AS start_work,
            data.started_at,
            max(data.finished_at) OVER (PARTITION BY (data.started_at)::date, data.user_id) AS finish_work,
            data.finished_at,
            data.started_at AS actual_started_at,
            data.finished_at AS actual_finished_at,
            data.created_at,
            data.updated_at,
            data.evaluations,
            organizations.properties,
            data.checkin_type_id,
            data.plan_created_today AS planned_today,
            COALESCE(data.checkin_plan_item_id, data.plan_item_id) AS plan_item_id,
            data.checkin_lite,
                CASE
                    WHEN ((data.checkin_id IS NULL) AND (data.plan_item_id IS NULL)) THEN true
                    ELSE false
                END AS checkin_lite_only
           FROM (((((((((( WITH checkins_and_plans AS (
                         SELECT checkins.id AS checkin_id,
                            checkins.plan_item_id AS checkin_plan_item_id,
                            NULL::integer AS plan_item_id,
                            checkins.user_id,
                            checkins.location_id,
                                CASE
                                    WHEN (((checkins.started_at)::date > (checkins.created_at)::date) OR ((checkins.finished_at)::date > (checkins.created_at)::date)) THEN (((checkins.created_at)::date - age(((checkins.finished_at)::date)::timestamp with time zone, ((checkins.started_at)::date)::timestamp with time zone)))::date
                                    ELSE (checkins.started_at)::date
                                END AS started_date,
                                CASE
                                    WHEN (((checkins.started_at)::date > (checkins.created_at)::date) OR ((checkins.finished_at)::date > (checkins.created_at)::date)) THEN ((((((checkins.created_at)::date - age(((checkins.finished_at)::date)::timestamp with time zone, ((checkins.started_at)::date)::timestamp with time zone)))::date || ' '::text) || (checkins.started_at)::time without time zone))::timestamp without time zone
                                    ELSE checkins.started_at
                                END AS started_at,
                                CASE
                                    WHEN ((checkins.finished_at)::date > (checkins.created_at)::date) THEN ((((checkins.created_at)::date || ' '::text) || (checkins.finished_at)::time without time zone))::timestamp without time zone
                                    ELSE checkins.finished_at
                                END AS finished_at,
                            checkins.evaluations,
                            checkins.checkin_type_id,
                            checkins.created_at,
                            checkins.updated_at,
                                CASE
                                    WHEN ((plan_items.created_at)::date = plans.thedate) THEN 1
                                    ELSE NULL::integer
                                END AS plan_created_today,
                            plan_items.planned_time,
                            checkins.first_visit_time,
                            0 AS checkin_lite
                           FROM ((checkins
                             LEFT JOIN plan_items ON (((checkins.plan_item_id = plan_items.id) AND (checkins.location_id = plan_items.location_id))))
                             LEFT JOIN plans ON ((plans.id = plan_items.plan_id)))
                          WHERE ((checkins.created_at)::date > (('now'::text)::date - '1 mon'::interval))
                        UNION ALL
                         SELECT NULL::integer AS checkin_id,
                            NULL::integer AS checkin_plan_item_id,
                            plan_items.id AS plan_item_id,
                            plans.inspector_id AS user_id,
                            plan_items.location_id,
                            plans.thedate AS started_date,
                            NULL::timestamp without time zone AS started_at,
                            NULL::timestamp without time zone AS finished_at,
                            NULL::json AS evaluations,
                            NULL::integer AS checkin_type_id,
                            NULL::timestamp without time zone AS created_at,
                            NULL::timestamp without time zone AS updated_at,
                                CASE
                                    WHEN ((plan_items.created_at)::date = plans.thedate) THEN 1
                                    ELSE NULL::integer
                                END AS plan_created_today,
                            plan_items.planned_time,
                            NULL::integer AS first_visit_time,
                                CASE
                                    WHEN ((timezone('+0UTC'::text, ((cl.started_at)::time without time zone)::time with time zone) < '06:30:00+00'::time with time zone) OR ((timezone('+0UTC'::text, ((cl.started_at)::time without time zone)::time with time zone) > '13:30:00+00'::time with time zone) AND (timezone('+0UTC'::text, ((cl.started_at)::time without time zone)::time with time zone) < '14:30:00+00'::time with time zone))) THEN 1
                                    ELSE 0
                                END AS checkin_lite
                           FROM (((plans
                             LEFT JOIN plan_items ON ((plans.id = plan_items.plan_id)))
                             LEFT JOIN checkins ON (((checkins.plan_item_id = plan_items.id) AND (checkins.location_id = plan_items.location_id))))
                             LEFT JOIN checkin_lites cl ON (((((cl.user_id = plans.inspector_id) AND (cl.location_id = plan_items.location_id)) AND ((cl.started_at)::date = plans.thedate)) AND (cl.plan_item_id = plan_items.id))))
                          WHERE ((((checkins.id IS NULL) AND (plan_items.id IS NOT NULL)) AND (plans.thedate > (('now'::text)::date - '1 mon'::interval))) AND (plans.thedate <= ('now'::text)::date))
                        UNION ALL
                         SELECT NULL::integer AS checkin_id,
                            NULL::integer AS checkin_plan_item_id,
                            NULL::integer AS plan_item_id,
                            cl.user_id,
                            cl.location_id,
                            (cl.started_at)::date AS started_date,
                            cl.started_at,
                            NULL::timestamp without time zone AS finished_at,
                            NULL::json AS evaluations,
                            NULL::integer AS checkin_type_id,
                            NULL::timestamp without time zone AS created_at,
                            NULL::timestamp without time zone AS updated_at,
                            0 AS plan_created_today,
                            NULL::integer AS planned_time,
                            NULL::integer AS first_visit_time,
                                CASE
                                    WHEN ((timezone('+0UTC'::text, ((cl.started_at)::time without time zone)::time with time zone) < '06:30:00+00'::time with time zone) OR ((timezone('+0UTC'::text, ((cl.started_at)::time without time zone)::time with time zone) > '13:30:00+00'::time with time zone) AND (timezone('+0UTC'::text, ((cl.started_at)::time without time zone)::time with time zone) < '14:30:00+00'::time with time zone))) THEN 1
                                    ELSE 0
                                END AS checkin_lite
                           FROM (checkin_lites cl
                             LEFT JOIN checkins ON ((((cl.user_id = checkins.user_id) AND (cl.location_id = checkins.location_id)) AND ((cl.started_at)::date = (checkins.started_at)::date))))
                          WHERE (((((checkins.id IS NULL) AND (cl.plan_item_id IS NULL)) AND ((timezone('+0UTC'::text, ((cl.started_at)::time without time zone)::time with time zone) < '06:30:00+00'::time with time zone) OR ((timezone('+0UTC'::text, ((cl.started_at)::time without time zone)::time with time zone) > '13:30:00+00'::time with time zone) AND (timezone('+0UTC'::text, ((cl.started_at)::time without time zone)::time with time zone) < '14:30:00+00'::time with time zone)))) AND ((cl.started_at)::date > (('now'::text)::date - '1 mon'::interval))) AND ((cl.started_at)::date <= ('now'::text)::date))
                        )
                 SELECT checkins_and_plans.checkin_id,
                    checkins_and_plans.checkin_plan_item_id,
                    checkins_and_plans.plan_item_id,
                    checkins_and_plans.user_id,
                    checkins_and_plans.location_id,
                    checkins_and_plans.started_date,
                    checkins_and_plans.started_at,
                    checkins_and_plans.finished_at,
                    checkins_and_plans.evaluations,
                    checkins_and_plans.checkin_type_id,
                    checkins_and_plans.created_at,
                    checkins_and_plans.updated_at,
                    checkins_and_plans.plan_created_today,
                    checkins_and_plans.planned_time,
                    checkins_and_plans.first_visit_time,
                    checkins_and_plans.checkin_lite
                   FROM checkins_and_plans
                  WHERE ((checkins_and_plans.created_at)::date IS NOT NULL)
                UNION ALL
                 SELECT plan.checkin_id,
                    plan.checkin_plan_item_id,
                    plan.plan_item_id,
                    plan.user_id,
                    plan.location_id,
                    plan.started_date,
                    plan.started_at,
                    plan.finished_at,
                    plan.evaluations,
                    plan.checkin_type_id,
                    plan.created_at,
                    plan.updated_at,
                    plan.plan_created_today,
                    plan.planned_time,
                    plan.first_visit_time,
                    plan.checkin_lite
                   FROM (checkins_and_plans plan
                     LEFT JOIN checkins_and_plans fact ON (((((plan.user_id = fact.user_id) AND (plan.location_id = fact.location_id)) AND (plan.started_date = fact.started_date)) AND (fact.checkin_id IS NOT NULL))))
                  WHERE ((fact.user_id IS NULL) AND (plan.user_id IS NOT NULL))) data
             JOIN users ON ((data.user_id = users.id)))
             LEFT JOIN inspector_locations ON (((inspector_locations.id = data.location_id) AND (inspector_locations.inspector_id = data.user_id))))
             LEFT JOIN locations ON ((locations.id = data.location_id)))
             LEFT JOIN location_types ON ((location_types.id = locations.location_type_id)))
             LEFT JOIN location_categories ON ((location_categories.id = locations.location_category_id)))
             LEFT JOIN companies ON ((companies.id = locations.company_id)))
             LEFT JOIN signboards ON ((signboards.id = locations.signboard_id)))
             LEFT JOIN organizations ON ((organizations.id = users.organization_id)))
             LEFT JOIN location_organizations ON (((organizations.id = location_organizations.organization_id) AND (locations.id = location_organizations.location_id))))
          WINDOW previous_checkin AS (PARTITION BY (data.started_at)::date, data.user_id ORDER BY data.finished_at DESC)) scorecard_checkins
  WITH NO DATA;
  --
  
