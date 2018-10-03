module Facades
  module WebApi
    module Admin
      module PhotoExports
        class PhotoCounter < ::Facades::Base
          include JoinsAndConditions

          def scope
            return @scope if defined?(@scope)
            @scope = Checkin

            @sql = <<~SQL
              :__locations_join__
              :__organizations_join__              
              :__user_versions_join__
              WHERE ("checkins"."completed_at" AT TIME ZONE 'UTC' AT TIME ZONE checkins.timezone 
                BETWEEN ':__date_from__'::timestamp AND ':__date_till__'::timestamp)
              AND checkins.photos_count > 0
              :__company_conditions__
              :__signboard_conditions__
              :__user_versions_conditions__  

            SQL

            set_common_conditions

            join_locations if params[:company_ids].present? || params[:signboard_ids].present?

            if params[:chief_id].present?
              join_user_versions
              set_user_version_conditions
            end

            set_company_conditions if params[:company_ids].present?
            set_signboard_conditions if params[:signboard_ids].present?

            clean_sql

            @scope.joins(sql)
          end


          def count
            scope.sum(:photos_count)
          end
        end
      end
    end
  end
end
