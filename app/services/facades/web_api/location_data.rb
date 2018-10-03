module Facades
  module WebApi
    class LocationData < SearchBase

      def by_name(data_field)
        return @by_name if defined?(@by_name)
        @by_name = scope
        @by_name = search(@by_name) if search_term.present?
        @by_name = @by_name.order(fields_for_order).
          group(:name).
          select("locations.data->>'#{data_field}' as name, json_agg(locations.id) as ids").
          limit(max_limit)
      end

      protected

      def scope
        return @scope if defined?(@scope)
        @scope = LocationType.accessible_by(ability, :read)
        @scope = @scope.joins(location: { organization_id: user.organization_ids } ) if params[:user_id]
        @scope
      end

      def search_fields
        @search_fields ||= ['locations.external_id']
      end

      def fields_for_uniq
        @fields_for_uniq ||= ['locations.external_id']
      end

      def fields_for_order
        @fields_for_order ||= ['locations.external_id']
      end

      private
      def ability
        @ability ||= LocationsFilteringAbility.new(user)
      end
    end
  end
end
