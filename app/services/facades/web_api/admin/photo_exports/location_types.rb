module Facades
  module WebApi
    module Admin
      module PhotoExports
        class LocationTypes < ::Facades::WebApi::LocationTypes

          def scope
            return @scope if defined?(@scope)
            @scope = LocationType.where(id: Photo.preselect("locations.location_type_id", params.permit!))
            @scope
          end

        end
      end
    end
  end
end
