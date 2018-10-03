module Facades
  module WebApi
    class Signboards < SearchBase

      def by_name
        return @by_name if defined?(@by_name)
        @by_name = scope.group(:name).select('signboards.name, json_agg(signboards.id) as ids').limit(max_limit)
      end

      protected

      def scope
        return @scope if defined?(@scope)
        @scope = Signboard.accessible_by(ability)
        @scope = @scope.where(company_id: params[:company_ids]) if params[:company_ids]
        @scope = @scope.recent_data_in_period(HISTORY_IN_DAYS)
        @scope
      end

      def search_fields
        @search_fields ||= ['signboards.name']
      end

      def fields_for_uniq
        @fields_for_uniq ||= ['name']
      end

      private
      def ability
        @ability ||= LocationsFilteringAbility.new(user)
      end
    end
  end
end
