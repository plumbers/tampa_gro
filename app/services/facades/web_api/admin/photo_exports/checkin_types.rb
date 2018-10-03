module Facades
  module WebApi
    module Admin
      module PhotoExports
        class CheckinTypes < ::Facades::WebApi::CheckinTypes

          def scope
            return @scope if defined?(@scope)
            @scope = CheckinTypeUnscoped.where(id: Photo.preselect("reports.checkin_type_id", params.permit!))
            @scope
          end

        end
      end
    end
  end
end
