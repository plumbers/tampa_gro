module Facades
  module WebApi
    class Companies < SearchBase

      def by_name
        return @by_name if defined?(@by_name)
        @by_name = scope
        @by_name = search(@by_name) if search_term.present?
        @by_name = @by_name.order(fields_for_order).
          group(:name).
          select('companies.name, json_agg(companies.id) as ids').
          limit(max_limit)
      end
      
      protected

      def scope
        return @scope if defined?(@scope)
        @scope = Company.accessible_by(ability, :read).joins(:organization)
        @scope = @scope.where(organizations: { business_id: params[:business_id] }) if params[:business_id]
        @scope = @scope.where(organization_id: user.organization_ids) if params[:user_id]
        @scope = @scope.recent_data_in_period(HISTORY_IN_DAYS)
        @scope
      end

      def search_fields
        @search_fields ||= ['companies.name']
      end

      def fields_for_uniq
        @fields_for_uniq ||= ['name']
      end

      def ability
        @ability ||= LocationsFilteringAbility.new(user)
      end

    end
  end
end
