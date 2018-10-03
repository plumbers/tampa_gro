module Facades
  module WebApi
    module Admin
      module PhotoExports
        class Questions < ::Facades::WebApi::Questions

          def scope
            return @scope if defined?(@scope)
            @scope = Question.where(id: Photo.preselect("photos.question_id", params.permit!))
            @scope
          end

        end
      end
    end
  end
end
