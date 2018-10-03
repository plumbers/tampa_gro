module Facades
  module WebApi
    module Admin
      module PhotoExports
        class Companies < ::Facades::WebApi::Companies

          def scope
            return @scope if defined?(@scope)
            @scope = Company.where(id: Photo.preselect("locations.company_id", params.permit!))
            @scope
          end

        end
      end
    end
  end
end
