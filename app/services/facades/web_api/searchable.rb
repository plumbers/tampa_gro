module Facades
  module WebApi
    module Searchable
      HISTORY_IN_DAYS = Rails.configuration.history_period_in_days_for_lenta_items

      def search(rel)
        search_sql = Array(search_fields).map { |field| "#{field} ilike :search_pattern" }.join(' OR ')
        rel.where(search_sql, search_pattern: search_pattern)
      end

      protected

      def search_pattern
        @search_pattern ||= if from_start
                              "#{search_term}%"
                            else
                              "%#{search_term}%"
                            end
      end


      def search_term
        @search_term ||= params[:search]
      end


    end
  end
end
