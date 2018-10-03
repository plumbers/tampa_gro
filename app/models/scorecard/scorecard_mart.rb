require 'etl'
require 'reports'
require 'report_tables'

class ScorecardMart < ActiveRecord::Base
  self.primary_key = 'scid'
  self.table_name  = "scorecard_mart_tbl"

  scope :today,     -> {where("(started_date = '%1$s' AND created_at IS NULL) OR (created_at::DATE = '%1$s')" % Date.today)}
  scope :yesterday, -> {where("(started_date = '%1$s' AND created_at IS NULL) OR (created_at::DATE = '%1$s')" % Date.yesterday)}
  scope :week_ago,  -> {where("(started_date BETWEEN '%1$s' AND '%2$s' AND created_at IS NULL) OR (created_at::DATE BETWEEN '%1$s' AND '%2$s')" % [Date.yesterday.beginning_of_week,  Date.yesterday])}
  scope :month_ago, -> {where("(started_date BETWEEN '%1$s' AND '%2$s' AND created_at IS NULL) OR (created_at::DATE BETWEEN '%1$s' AND '%2$s')" % [Date.yesterday.beginning_of_month, Date.yesterday])}

  scope :checkins_for_period,   ->(date_from, date_to){
                where("(fact_checkins=1 OR unplanned_checkins=1) AND created_at::DATE BETWEEN ? AND ?", date_from, date_to) }
  scope :plan_items_for_period, ->(date_from, date_to){
                where("planned_checkins IN (1,2) AND started_date BETWEEN ? AND ?", date_from, date_to) }
  scope :for_merch, ->(merch_ids){ where("uid IN (?)", merch_ids) }

  scope :checkins_for_merch_ids_in_period,  ->(merch_ids, date_from, date_to) {for_merch(merch_ids).checkins_for_period(date_from, date_to)}
  scope :grouped_by_period,                 ->{group("started_date, region_code, merchendising_type, agency_name")}

  scope :plan_items_for_merch_ids_in_period,->(merch_ids, date_from, date_to) {for_merch(merch_ids).plan_items_for_period(date_from, date_to)}

  scope :get_sum,          ->{ all.to_a.map(&:sum).inject(:+)||0 }
  scope :get_count,        ->{ all.to_a.map(&:count).inject(:+)||0 }
  scope :count_routes,     ->{ select("COUNT(DISTINCT COALESCE(NULLIF(route_id, 'заменен мерчандайзер или нет в АП'), uid::text))").get_count }
  scope :count_locations,  ->{ select("COUNT(DISTINCT location_id)").get_count }
  scope :count_plan_items, ->{ select("COUNT(DISTINCT plan_item_id)").get_count }
  scope :count_checkins,   ->{ select("COUNT(DISTINCT checkin_id)").get_count }

  scope :start_morning_counter, ->{ select("SUM(started_morning)").get_sum }
  scope :finish_evening_counter,->{ select("SUM(finished_evening)").get_sum }

  scope :fact_sale_point_time,  ->{ select("SUM(fact_sale_point_time)/60.0 sum").get_sum }
  scope :fact_travel_time,      ->{ select("SUM(fact_travel_time)/60.0 sum").get_sum }
  scope :fact_total_time,       ->{ select("SUM(fact_sale_point_time + fact_travel_time)/60.0 sum").get_sum }

  scope :planned_sale_point_time,  ->{ select("SUM(COALESCE(sale_point_time, 0.0))/60.0 sum").get_sum }
  scope :planned_travel_time,      ->{ select("SUM(COALESCE(travel_time, 0.0))/60.0 sum").get_sum }
  scope :planned_total_time,       ->{ select("SUM(COALESCE(sale_point_time, 0.0) + COALESCE(travel_time, 0.0))/60.0 sum").get_sum }

  scope :except_checkin_lite,      ->{ where("NOT checkin_lite_only") }

  PERIODS = [
      'today','yesterday','week','month'
  ].freeze

  ALL_CACHED_COLUMNS  = PepsiReport::ScorecardStatistics::Generator::ALL_CACHED_COLUMNS
  STAT_FIRST_POS      = ALL_CACHED_COLUMNS.index "dimension_type_"
  STATS_COLUMNS       = ALL_CACHED_COLUMNS[STAT_FIRST_POS..-1].freeze

  class << self

    def refresh_data_marts_and_cache
      puts "refresh_scorecard_reports_data_marts started"
      refresh_scorecard_reports_data_marts
      puts "full_update_cached_stats started"
      full_update_cached_stats
    end

    def recreate_data_marts_tables_and_cache
      puts "recreate_data_marts_tables started"
      recreate_data_marts_tables
      puts "full_update_cached_stats started"
      full_update_cached_stats
    end

    def refresh_data_marts_tables_and_cache
      puts "refresh_scorecard_reports_data_marts started"
      increment_update_data_marts_tables
      puts "full_update_cached_stats started"
      partial_update_cached_stats
    end

    def recreate_data_marts_tables
      # ScorecardMart.recreate_data_marts_tables
      StatisticsUpdateLog.add_step 're-create (empty) stats views && tables'
      time_split = Time.now
      etl  = ETL.new(description: "this ETL prepare DB = {DDL && data} for scorecard reports",
                     logger: no_sql_logger
      )
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        etl.connection=connection
        Reports::DataMartTables.constants.each do |mart|
          # ActiveRecord::Base.transaction do
            module_mart = "Reports::DataMartTables::#{mart}".constantize
            # puts module_mart
            module_mart.ensure_for_exists etl
          # end
        end
      end
      create_cached_stats
      StatisticsUpdateLog.end_step 'COMPLETE'
      puts "Recreate data marts tables takes: #{(Time.now-time_split).to_i} sec"
    end

    def increment_update_data_marts_tables
      # ScorecardMart.increment_update_data_marts_tables
      StatisticsUpdateLog.add_step 'increment update started'
      time_split = Time.now
      etl  = ETL.new(description: "this ETL prepare DB = {DDL && data} for scorecard reports",
                     logger: no_sql_logger
      )
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        etl.connection=connection
        # Reports::DataMartsTables.constants.select{|t| t=~/ScorecardCheckinsMart|ScorecardMart/}.each do |mart|
        ['ScorecardCheckinsMart', 'ScorecardMart'].each do |mart|
          module_mart = "Reports::DataMartTables::#{mart}".constantize
          # ActiveRecord::Base.transaction do
            module_mart.delta_update etl
          # end
        end
      end
      StatisticsUpdateLog.end_step 'COMPLETE'
      puts "Increment update data marts tables takes: #{(Time.now-time_split).to_i} sec"
    end

    def scorecard_statistics_cached(start_date:, finish_date:, user_id:)
      period = get_period start_date
      statement = %[

SELECT
'ttl' dimension_merch_type_or_agency_name_,
'ttl' dimension_type_,

MAX(route_planned_) route_planned_,
MAX(route_fact_) route_fact_,
MAX(route_ratio_) route_ratio_,

MAX(loca_planned_) loca_planned_,
MAX(loca_fact_) loca_fact_,
MAX(loca_ratio_) loca_ratio_,

MAX(planned_count_) planned_count_,
MAX(fact_count_) fact_count_,
MAX(unplanned_count_) unplanned_count_,
MAX(all_visits_) all_visits_,
MAX(visits_ratio_) visits_ratio_,

MAX(fact_sale_point_time_hrs_) fact_sale_point_time_hrs_,
MAX(fact_travel_time_hrs_) fact_travel_time_hrs_,
MAX(fact_total_time_hrs_) fact_total_time_hrs_,

MAX(planned_sale_point_time_hrs_) planned_sale_point_time_hrs_,
MAX(planned_travel_time_hrs_) planned_travel_time_hrs_,
MAX(planned_total_time_hrs_) planned_total_time_hrs_,

MAX(started_morning_ratio_) started_morning_ratio_,
MAX(finished_evening_ratio_) finished_evening_ratio_,

MAX(started_morning_) started_morning_,
MAX(finished_evening_) finished_evening_

FROM scorecard_chiefs_stats
WHERE period='#{period}' AND user_id=#{user_id} AND dimension_type_ IN ('ttl','ttl2')

UNION ALL

SELECT * FROM
(
  SELECT dimension_merch_type_or_agency_name_, #{STATS_COLUMNS.join(',')}
  FROM scorecard_chiefs_stats
  WHERE period='#{period}' AND user_id=#{user_id} AND dimension_type_ NOT IN ('ttl','ttl2')
  ORDER BY planned_count_ DESC, fact_count_ DESC, unplanned_count_ DESC
)DIMENSIONS_DATA

]

      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute statement
      end
    end

    def scorecard_statistics(start_date:, finish_date:, user_id:)
      statement = %[
SELECT * FROM scorecard_totals('#{start_date}','#{finish_date}',#{user_id})
UNION ALL
SELECT * FROM scorecard_aggregates('#{start_date}','#{finish_date}',#{user_id})
      ]

      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute statement
      end
    end

    def refresh_scorecard_reports_data_marts #concurrently = true
      time_split = Time.now
      etl  = ETL.new(description: "this ETL prepare DB = {DDL && data} for scorecard reports",
                     logger: no_sql_logger
      )
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          etl.connection=connection
          Reports::DataMarts.constants.each do |mart|
            module_mart = "Reports::DataMarts::#{mart}".constantize
            # puts "#{module_mart} refresh started"
            # module_mart.refresh etl, concurrently ? ' CONCURRENTLY ' : ''
            module_mart.ensure_for_exists etl
            # puts module_mart.query
          end
        end
      end
      puts "Refresh data marts takes: #{(Time.now-time_split).to_i} sec"
    end

    def clear_scorecard_data_marts
      etl  = ETL.new(description: "this ETL prepare DB = {DDL && data} for scorecard reports",
                     logger: no_sql_logger
      )
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          statement = %[
DROP FUNCTION IF EXISTS scorecard_aggregates(start_date VARCHAR(10), finish_date VARCHAR(10), user_id BIGINT);
DROP FUNCTION IF EXISTS scorecard_aggregates(start_date VARCHAR(10), finish_date VARCHAR(10), stat_user_id BIGINT);

DROP   MATERIALIZED VIEW IF EXISTS  scorecard_users_hierarchy2 CASCADE;
DROP   MATERIALIZED VIEW IF EXISTS  scorecard_address_program_data CASCADE;
DROP   MATERIALIZED VIEW IF EXISTS  scorecard_exclusions CASCADE;
DROP   MATERIALIZED VIEW IF EXISTS  scorecard_checkins CASCADE;
DROP   MATERIALIZED VIEW IF EXISTS  scorecard_mart CASCADE;
DROP   MATERIALIZED VIEW IF EXISTS  scorecard_times_mart CASCADE;
DROP   MATERIALIZED VIEW IF EXISTS  scorecard_regions CASCADE;
DROP   MATERIALIZED VIEW IF EXISTS  scorecard_regional_managers CASCADE;
DROP   MATERIALIZED VIEW IF EXISTS  scorecard_agencies CASCADE;
DROP   MATERIALIZED VIEW IF EXISTS  scorecard_checkin_types CASCADE;
]
          connection.execute statement
          etl.connection=connection
          Reports::DataMarts.constants.each do |mart|
            module_mart = "Reports::DataMarts::#{mart}".constantize
            module_mart.ensure_for_exists etl, 'WITH NO DATA'
          end
        end
      end
      create_cached_stats
    end

    # creates scorecard_chiefs_stats table on the fly - the statistics cache
    def create_cached_stats
      statement = %[
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_class WHERE relname = '#{ScorecardChiefsStats.table_name}')
  THEN
    IF (SELECT count(a.attname)
        FROM pg_class c, pg_attribute a, pg_type t
        WHERE c.relname = '#{ScorecardChiefsStats.table_name}'
        AND a.attnum > 0
        AND a.attrelid = c.oid
        AND a.atttypid = t.oid)!=(#{STATS_COLUMNS.count+6})
    THEN
      DROP TABLE #{ScorecardChiefsStats.table_name};
    END IF;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = '#{ScorecardChiefsStats.table_name}')
  THEN

    CREATE TABLE #{ScorecardChiefsStats.table_name} AS
    SELECT dimension_merch_type_or_agency_name_, #{STATS_COLUMNS.join(',')}, CURRENT_TIMESTAMP created_at, ''::text period, 0 user_id
    FROM scorecard_aggregates('#{Date.today}','#{Date.today}', (SELECT id FROM users WHERE role='teamlead' LIMIT 1));

    TRUNCATE TABLE #{ScorecardChiefsStats.table_name};
    ALTER TABLE #{ScorecardChiefsStats.table_name} ADD COLUMN id BIGSERIAL PRIMARY KEY;

  END IF;
END;
$$ LANGUAGE plpgsql;
]
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute statement
      end
    end

    # full update scorecard_chiefs_stats table
    def full_update_cached_stats
      StatisticsUpdateLog.add_step 'Full update stats table'
      ScorecardChiefsStats.update_all(created_at: Date.yesterday)
      time_split = Time.now
      today = Date.today
      yesterday = Date.yesterday
      chiefs_list.each do |user_id_|
          orig_user_id, user_id = user_id_, subordinate_executives_for(user_id_)
          PERIODS.each do |period|
              case period
                when 'today' then
                  start_date, finish_date = today, today
                when 'yesterday' then
                  start_date, finish_date = yesterday, yesterday
                when 'week' then
                  start_date, finish_date = yesterday.beginning_of_week,  yesterday
                when 'month' then
                  start_date, finish_date = yesterday.beginning_of_month, yesterday
              end
              if period=='today'
                ActiveRecord::Base.transaction do
                  statement = %[
DELETE FROM scorecard_chiefs_stats WHERE period='#{period}' AND user_id=#{orig_user_id};

INSERT INTO scorecard_chiefs_stats(dimension_merch_type_or_agency_name_, #{STATS_COLUMNS.join(',')},created_at,period,user_id)
SELECT dimension_merch_type_or_agency_name_, #{STATS_COLUMNS.join(',')},
CURRENT_TIMESTAMP created_at,
'#{period}'::text period,
#{orig_user_id} user_id
FROM scorecard_totals('#{start_date}', '#{finish_date}', #{user_id})
UNION ALL
SELECT dimension_merch_type_or_agency_name_, #{STATS_COLUMNS.join(',')},
CURRENT_TIMESTAMP created_at,
'#{period}'::text period,
#{orig_user_id} user_id
FROM scorecard_aggregates('#{start_date}', '#{finish_date}', #{user_id});
]
                  ActiveRecord::Base.connection_pool.with_connection do |connection|
                    connection.execute statement
                  end
                end
              else

                ActiveRecord::Base.transaction do
                  statement = %[

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM scorecard_chiefs_stats
                          WHERE created_at::DATE='#{Date.today}'::DATE AND
                                period='#{period}' AND
                                user_id=#{orig_user_id})
  THEN

    DELETE FROM scorecard_chiefs_stats WHERE created_at::DATE!='#{Date.today}'::DATE AND period='#{period}' AND user_id=#{orig_user_id};

    INSERT INTO scorecard_chiefs_stats(dimension_merch_type_or_agency_name_, #{STATS_COLUMNS.join(',')},created_at,period,user_id)
    SELECT dimension_merch_type_or_agency_name_, #{STATS_COLUMNS.join(',')},
    CURRENT_TIMESTAMP created_at, '#{period}'::text period, #{orig_user_id} user_id
    FROM scorecard_totals('#{start_date}', '#{finish_date}', #{user_id})
    UNION ALL
    SELECT dimension_merch_type_or_agency_name_, #{STATS_COLUMNS.join(',')},
    CURRENT_TIMESTAMP created_at, '#{period}'::text period, #{orig_user_id} user_id
    FROM scorecard_aggregates('#{start_date}', '#{finish_date}', #{user_id});

  END IF;
END;
$$ LANGUAGE plpgsql;

]
                  ActiveRecord::Base.connection_pool.with_connection do |connection|
                    connection.execute statement
                  end
                end
              end
        end
      end
      StatisticsUpdateLog.end_step 'COMPLETE'
      puts "Update cached stats takes: #{(Time.now-time_split).to_i} sec"
    end

    # partial update scorecard_chiefs_stats table - daily only
    def partial_update_cached_stats
      StatisticsUpdateLog.add_step 'Partial update stats table'
      time_split = Time.now
      today = Date.today
      chiefs_list.each do |user_id_|
        orig_user_id, user_id = user_id_, subordinate_executives_for(user_id_)
        start_date, finish_date = today, today

        ActiveRecord::Base.transaction do
          statement = %[
DELETE FROM scorecard_chiefs_stats WHERE period='today' AND user_id=#{orig_user_id};

INSERT INTO scorecard_chiefs_stats(dimension_merch_type_or_agency_name_, #{STATS_COLUMNS.join(',')},created_at,period,user_id)
SELECT dimension_merch_type_or_agency_name_, #{STATS_COLUMNS.join(',')},
CURRENT_TIMESTAMP created_at,
'today'::text period,
#{orig_user_id} user_id
FROM scorecard_totals('#{start_date}', '#{finish_date}', #{user_id})
UNION ALL
SELECT dimension_merch_type_or_agency_name_, #{STATS_COLUMNS.join(',')},
CURRENT_TIMESTAMP created_at,
'today'::text period,
#{orig_user_id} user_id
FROM scorecard_aggregates('#{start_date}', '#{finish_date}', #{user_id});
]
                  ActiveRecord::Base.connection_pool.with_connection do |connection|
                    connection.execute statement
                  end
        end
      end
      StatisticsUpdateLog.end_step 'COMPLETE'
      puts "Update cached stats takes: #{(Time.now-time_split).to_i} sec"
    end

    private

    def get_period start_date
      if start_date==Date.today
        'today'
      elsif start_date==Date.yesterday
        'yesterday'
      elsif start_date==Date.yesterday.beginning_of_week
        'week'
      elsif start_date==Date.yesterday.beginning_of_month
        'month'
      end
    end

    def chiefs_list
      User.unscoped.where("role!='merchendiser' AND role IS NOT NULL AND (deleted_at IS NULL OR deleted_at>(CURRENT_DATE - INTERVAL '45 day'))")
          .order("CASE WHEN role in ('director','president','head_manager','ceo','manager','regional_manager','executive') THEN 1 ELSE 2 END")
          .pluck(:id)
    end

    def ceo_w_executives
      ceo = User.unscoped.where(role: ceo).select{|ceo| ceo if ceo.find_all_by_generation(3).pluck(:id).count>1}
      ceo
    end

    def subordinate_executives_for user_id
      executives = User.unscoped.where(id: user_id).first.descendants.where(role: ['executive']).all
      if executives.blank?||executives.count>1
        user_id
      else
        executives.last.id
      end
    end

    def no_sql_logger
      ::Logger.new(STDOUT).tap do |logger|
        logger.sev_threshold = Logger::ERROR
        logger.formatter = proc do |severity, datetime, progname, msg|
          lead =  "[#{datetime}] #{severity} #{msg[:event_type]}"
          desc =  "\"#{msg[:emitter].description || 'no description given'}\""
          # desc += " (object #{msg[:emitter].object_id})"

          case msg[:event_type]
            when :query_start
              # "#{lead} for #{desc}\n#{msg[:sql]}\n"
            when :query_complete
              # "#{lead} for #{desc} #{progname} runtime: #{msg[:runtime]}s\n"
            else
              "#{msg}"
          end
        end
      end
    end

  end

end