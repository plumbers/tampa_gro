module Facades
  module WebApi
    module Admin
      module PhotoExports
        class Signboards < ::Facades::WebApi::Signboards

          def scope
            return @scope if defined?(@scope)
            @scope = Signboard.where(id: Photo.preselect("locations.signboard_id", params.permit!))
            @scope
          end

        end
      end
    end
  end
end
