module Facades
  module WebApi
    class LocationTypes < SearchBase

      def by_name
        return @by_name if defined?(@by_name)
        @by_name = scope
        @by_name = search(@by_name) if search_term.present?
        @by_name = @by_name.order(fields_for_order).
          group(:name).
          select('location_types.name, json_agg(location_types.id) as ids').
          limit(max_limit)
      end

      protected

      def scope
        return @scope if defined?(@scope)
        @scope = LocationType.accessible_by(ability, :read)
        @scope = @scope.where(organization_id: user.organization_ids) if params[:user_id]
        @scope
      end

      def search_fields
        @search_fields ||= ['location_types.name']
      end

      def fields_for_uniq
        @fields_for_uniq ||= ['name']
      end

      def fields_for_order
        @fields_for_order ||= ['location_types.name']
      end

      private
      def ability
        @ability ||= LocationsFilteringAbility.new(user)
      end
    end
  end
end
