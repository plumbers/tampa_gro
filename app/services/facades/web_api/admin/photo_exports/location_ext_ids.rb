module Facades
  module WebApi
    module Admin
      module PhotoExports
        class LocationExtIds < ::Facades::WebApi::LocationExtIds

          def scope
            return @scope if defined?(@scope)
            @scope = LocationUnscoped.where(id: Photo.preselect("locations.id", params.permit!))
            @scope
          end

        end
      end
    end
  end
end
