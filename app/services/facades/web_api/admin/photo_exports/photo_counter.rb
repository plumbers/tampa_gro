module Facades
  module WebApi
    module Admin
      module PhotoExports
        class PhotoCounter < ::Facades::Base

          def scope
            return @scope if defined?(@scope)
            @scope = Photo.count_filtered(params.permit!, 200_000).order(nil)
            @scope
          end

          def count
            scope.select("count(photos.id)").first[:count]
          end
        end
      end
    end
  end
end
