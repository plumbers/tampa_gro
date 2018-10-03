module Facades
  module WebApi
    module Admin
      module PhotoExports
        module JoinsAndConditions
          extend ActiveSupport::Concern

          included do
            attr_accessor :sql

            LOCATIONS_JOIN ||= <<-SQL
              INNER JOIN locations  ON locations.id = checkins.location_id
            SQL

            USER_VERSIONS_JOIN ||= <<-SQL
              INNER JOIN LATERAL(
                SELECT user_versions.h_vector FROM user_versions
                WHERE user_versions.item_id = checkins.user_id
                AND user_versions.created_at < checkins.completed_at
                ORDER BY created_at DESC
                LIMIT 1
              ) uv on true
            SQL

            ORGANIZATIONS_JOIN ||= <<-SQL
              INNER JOIN organizations ON organizations.id = checkins.organization_id
              AND organizations.business_id = :__business_id__
            SQL
          end

          def join_locations
            self.sql = sql.gsub(':__locations_join__', LOCATIONS_JOIN)
          end

          def join_user_versions
            self.sql = sql.gsub(':__user_versions_join__', USER_VERSIONS_JOIN)
                         .gsub(':__user_versions_conditions__', "AND uv.h_vector @> '#{params[:chief_id]}'")
          end

          def set_common_conditions
            self.sql = sql.gsub(':__organizations_join__', ORGANIZATIONS_JOIN)
                         .gsub(':__date_from__', Date.parse(params[:date_from]).to_s)
                         .gsub(':__date_till__', Date.parse(params[:date_till]).end_of_day.to_s)
                         .gsub(':__business_id__', params[:business_id].to_s)
          end

          def set_company_conditions
            self.sql = sql.gsub(':__company_conditions__', "AND locations.company_id IN (#{params[:company_ids].join(',')})")
          end

          def set_signboard_conditions
            self.sql = sql.gsub(':__signboard_conditions__', "AND locations.signboard_id IN (#{params[:signboard_ids].join(',')})")
          end

          def set_user_version_conditions
            self.sql = sql.gsub(':__user_versions_conditions__', "AND uv.h_vector @> '#{params[:chief_id]}'")
          end

          def clean_sql
            self.sql = sql.gsub(/\:__.+?__/, '')
          end

        end
      end
    end
  end
end
