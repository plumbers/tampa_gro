module Facades
  module WebApi
    class Questions < SearchBase

      def by_name
        return @by_name if defined?(@by_name)
        @by_name = scope
        @by_name = search(@by_name) if search_term.present?
        @by_name = @by_name.order(fields_for_order).
          group(:name).
          select('questions.title as name, json_agg(questions.id) as ids').
          limit(max_limit)
      end

      protected

      def scope
        return @scope if defined?(@scope)
        @scope = Question.accessible_by(ability, :read)
        @scope = @scope.where(organization_id: user.organization_ids) if params[:user_id]
        @scope
      end

      def search_fields
        @search_fields ||= ['questions.title']
      end

      def fields_for_uniq
        @fields_for_uniq ||= ['title']
      end

      def fields_for_order
        ['title']
      end

      def fields_for_order
        @fields_for_order ||= ['questions.title']
      end

      private
      def ability
        @ability ||= QuestionsFilteringAbility.new(user)
      end
    end
  end
end
