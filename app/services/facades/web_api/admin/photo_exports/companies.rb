module Facades
  module WebApi
    module Admin
      module PhotoExports
        class Companies < ::Facades::WebApi::Companies
          include JoinsAndConditions

          def scope
            return @scope if defined?(@scope)

            @scope = Company.accessible_by(ability, :read)

            self.sql = <<~SQL
              INNER JOIN LATERAL(
                SELECT DISTINCT locations.company_id FROM locations
                INNER JOIN checkins ON checkins.location_id = locations.id
                :__organizations_join__              
                :__user_versions_join__
                WHERE ("checkins"."completed_at" AT TIME ZONE 'UTC' AT TIME ZONE checkins.timezone 
                  BETWEEN ':__date_from__'::timestamp AND ':__date_till__'::timestamp)
                AND checkins.photos_count > 0
                :__user_versions_conditions__
              ) t on t.company_id = companies.id
            SQL

            set_common_conditions

            if params[:chief_id].present?
              join_user_versions
              set_user_version_conditions
            end

            clean_sql

            @scope.joins(sql)
          end
        end
      end
    end
  end
end
