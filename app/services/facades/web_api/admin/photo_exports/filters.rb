module Facades
  module WebApi
    module Admin
      module PhotoExports
        module Filters
          extend ActiveSupport::Concern

          included do
            CHECKIN_STARTED_DATE     = "(checkins.completed_at AT TIME ZONE 'UTC' AT TIME ZONE checkins.timezone)"

            scope :with_dependencies, -> {
              joins(<<~SQL
                INNER JOIN checkins                 ON checkins.id                = photos.checkin_id
                LEFT JOIN reports                   ON reports.id                 = photos.report_id
                INNER JOIN users                    ON users.id                   = checkins.user_id
                INNER JOIN organizations            ON organizations.id           = checkins.organization_id
                INNER JOIN locations                ON locations.id               = checkins.location_id     AND locations.organization_id = organizations.id
                LEFT JOIN location_types            ON locations.location_type_id = location_types.id
                INNER JOIN checkin_types            ON checkin_types.id           = reports.checkin_type_id
                LEFT  JOIN questions                ON questions.id               = photos.question_id
                INNER JOIN signboards               ON locations.signboard_id     = signboards.id
                INNER JOIN companies                ON locations.company_id       = companies.id
                        INNER JOIN LATERAL(
                          SELECT user_versions.h_vector,item_id uv_user_id FROM user_versions
                          WHERE user_versions.item_id = users.id
                          AND user_versions.created_at < checkins.completed_at
                          ORDER BY created_at DESC
                          LIMIT 1
                        ) uv ON uv_user_id = users.id
              SQL
              )
            }

            scope :date_from,           ->(started_date_from) { where("#{CHECKIN_STARTED_DATE} >= ?", started_date_from) }
            scope :date_till,           ->(started_date_till) { where("#{CHECKIN_STARTED_DATE} <= ?", started_date_till.to_date.end_of_day.to_s) }
            scope :location_type_id,    ->(location_type_id) { where('locations.location_type_id IN (?)', location_type_id) }
            scope :chief_id,            ->(chief_id){ where('uv.h_vector @> ?', chief_id.to_s) }
            scope :business_id,         ->(business_id) { where('organizations.business_id IN (?)', business_id) }
            scope :location_ids,        ->(location_ids) { where('locations.id IN (?)', location_ids) }
            scope :location_ext_ids,    ->(location_ext_ids) { where('locations.external_id IN (?)', location_ext_ids) }
            scope :aws_uploaded,        -> { where.not(aws_image_file_name: nil) }
            scope :question_linked,     -> { where.not(question_id: nil) }
            scope :question_not_linked, -> { where(question_id: nil) }

            scope :company_ids,         ->(company_ids) { where('locations.company_id IN (?)', company_ids) }
            scope :signboard_ids,       ->(signboard_ids) { where('locations.signboard_id IN (?)', signboard_ids) }
            scope :organization_ids,    ->(organization_ids) { where('locations.organization_id IN (?)', organization_ids) }
            scope :exclude_dates,       ->(dates_to_exclude) { where("#{CHECKIN_STARTED_DATE} NOT IN (?)", dates_to_exclude) }
            scope :checkin_type_ids,    ->(checkin_type_ids) { where("checkin_types.id IN (?)", checkin_type_ids) }
            scope :question_ids,        ->(question_ids) { where(question_id: question_ids) }
            scope :checkin_ids,         ->(checkin_ids) { where("checkins.id IN (?)", checkin_ids) }
            scope :exclude_photo_ids,   ->(photo_ids) { where("photos.id NOT IN (?)", photo_ids) }
            scope :location_field_ids,  ->(location_ids) { where('locations.id IN (?)', location_ids) }

            scope_accessible :date_from, :date_till, :organization_ids,
                             :business_id, :chief_id,
                             :location_ids, :location_ext_ids,
                             :signboard_ids, :company_ids,
                             :location_type_id, :checkin_type_ids,
                             :location_type_ids, #:date_exclude,
                             :question_ids, :checkin_ids,
                             :exclude_photo_ids,
                             :location_field_ids

            def self.filtered(filters)
              filters = HashWithIndifferentAccess.new(filters)

              select_sql = <<-SQL.strip.gsub(':checkin_started_date', CHECKIN_STARTED_DATE)
                REPLACE(locations.external_id, '*', '#') AS external_id,
                :checkin_started_date AS started_date,
                users.business_id,
                checkins.timezone,
                photos.*,
                companies.name company_name,
                questions.title question_title,
                location_types.name location_type_name
              SQL

              rel = with_dependencies
              rel = rel.chief_id(filters[:chief_id]) if filters[:chief_id].present?
              rel.
                  select(select_sql).
                  periscope(filters).
                  limit(filters[:limit])
            end

            def self.preselect(pluck_field, params, limit = 300)
              self.filtered(params.to_h.merge(limit: limit)).pluck(pluck_field)
            end

            def self.count_filtered(params, limit = 20000)
              with_dependencies.periscope(params.to_h).limit(limit)
            end

            def self.filtering_by_orgs chief_mobile
              return @filtering_by_orgs if defined? @filtering_by_orgs
              stmnt = <<-SQL
                SELECT DISTINCT organization_id
                FROM users  u
                WHERE
                u.id IN ( SELECT descendant_id
                  FROM user_hierarchies
                  WHERE ancestor_id IN ( SELECT id
                  FROM users
                  WHERE mobile_phone like '%#{chief_mobile}'
                  AND deleted_at IS NULL )
                )
              SQL
              @filtering_by_orgs = find_by_sql(stmnt).to_a.map{|o| o["organization_id"]}.compact
              @filtering_by_orgs
            end

            def self.filtering_by_questionaries org_ids, questionarie_names, questions = ['']
              return @filtering_by_questionaries if defined? @filtering_by_questionaries
              questionarie_names_or_stamnt = questionarie_names.map{ |questionarie_name| "name ILIKE '%#{questionarie_name}%'" }.join ' OR '
              questions_or_stamnt = questions.map{ |question| "q.title ILIKE '%#{question}%'" }.join ' OR '
              stmnt = <<-SQL
                SELECT distinct q.id question_id
                FROM questions q
                INNER JOIN checkin_types ct ON ct.id=q.checkin_type_id
                WHERE (#{questions_or_stamnt})
                AND (#{questionarie_names_or_stamnt})
                AND organization_id IN (#{org_ids.join ','})
              SQL
              @filtering_by_questionaries = find_by_sql(stmnt).map{|o| o["question_id"]}.compact
              @filtering_by_questionaries
            end

            def self.filtering_by_signboards org_ids, signboard_names
              return @filtering_by_signboards if defined? @filtering_by_signboards
              signboard_names_or_stamnt = signboard_names.map{ |signboard_name| "name ILIKE '%#{signboard_name}%'" }.join ' OR '
              stmnt = <<-SQL
                SELECT distinct id signboard_id
                FROM signboards q
                WHERE (#{signboard_names_or_stamnt})
                AND organization_id IN (#{org_ids.join ','})
              SQL
              @filtering_by_signboards = find_by_sql(stmnt).map{|o| o["signboard_id"]}.compact
              @filtering_by_signboards
            end

            def self.filtering_by_location_types org_ids, location_type_names
              return @filtering_by_location_types if defined? @filtering_by_location_types
              location_type_names_or_stamnt = location_type_names.map{ |location_type_name| "name ILIKE '%#{location_type_name}%'" }.join ' OR '
              stmnt = <<-SQL
                SELECT DISTINCT lt.id location_type_id
                FROM locations l
                INNER JOIN location_types lt ON l.location_type_id=lt.id
                INNER JOIN organizations o ON o.id=l.organization_id
                WHERE (#{location_type_names_or_stamnt})
                AND organization_id IN (#{org_ids.join ','})
              SQL
              @filtering_by_location_types = find_by_sql(stmnt).map{|o| o["location_type_id"]}.compact
              @filtering_by_location_types
            end

            def self.filtering_by_location_data_field org_ids, location_field_name, location_field_values
              return @filtering_by_locations_field if defined? @filtering_by_locations_field
              location_type_names_or_stamnt = location_field_values.map{ |field_value| "(data->>'#{location_field_name}') = '#{field_value}'" }.join ' OR '
              stmnt = <<-SQL
                SELECT DISTINCT l.id location_field_ids
                FROM locations l
                INNER JOIN organizations o ON o.id=l.organization_id
                WHERE (#{location_type_names_or_stamnt})
                AND organization_id IN (#{org_ids.join ','})
              SQL
              @filtering_by_locations_field = find_by_sql(stmnt).map{|o| o["location_field_ids"]}.compact
              @filtering_by_locations_field
            end

          end
        end
      end
    end
  end
end
