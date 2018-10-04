class ScorecardHistogram < ActiveRecord::Base
  self.table_name  = 'scorecard_histogram'

  scope :requester,       ->(user_id){ where("h_vector @> '?'", user_id) }

  def self.reload_rows requester_id
    current_edge_id = ScorecardHistogram.requester(requester_id).maximum(:id)
    new_scorecard_cache = select_new_records requester_id
    return if new_scorecard_cache.empty?
    ActiveRecord::Base.transaction do
      batch_import_records(self, new_scorecard_cache)
      ScorecardHistogramQuestion.reload_rows requester_id
      update_dimensions
      ScorecardHistogramFact.reload_rows requester_id, current_edge_id
    end
  end

  private

  def self.select_new_records requester_id

    data_source_1 = ScorecardCache.only_new_cache.joins("INNER JOIN checkins ON checkins.id = event_id and checkins.checkin_type_id!=3").
        select("scorecard_caches.id, event_local_date, answers a, event, h_vector").
        requester(requester_id).
        where("event_type='Checkin'")

    selected_fields = <<-SQL
        id scid,
        JSONB_OBJECT_KEYS(a) question,
        ROW_TO_JSON(JSONB_EACH(a))->>'value' answer,
        h_vector,
        event_local_date,
        event->>'channel'         channel,
        event->>'iformat'         iformat,
        event->>'company_name'    company_name,
        event->>'network_name'    network_name,
        event->>'signboard_name'  signboard_name,
        event->>'client_category' client_category
    SQL

    data_source_2 = self.select(selected_fields).from(Arel.sql("(#{data_source_1.to_sql}) as d1"))

    outer_selected_fields = <<-SQL
      scid,
      SUBSTRING(question from 'value\/(.*)') question,
      CASE
        WHEN SUBSTRING(lower(answer::text) from 'true|yes|да|.*true.*|.*yes.*|.*да.*')!='' THEN 1.0
        WHEN SUBSTRING(lower(answer::text) from 'false|no|нет|.*false.*|.*no.*|.*нет.*')!='' THEN 0.0
        WHEN answer IS NULL THEN 0.0
        ELSE answer::numeric
      END answer,
      CASE
        WHEN SUBSTRING(lower(answer::text) from 'true|yes|да|.*true.*|.*yes.*|.*да.*')  ='' AND
             SUBSTRING(lower(answer::text) from 'false|no|нет|.*false.*|.*no.*|.*нет.*')='' THEN
          CASE
            WHEN SUBSTRING(question from 'Цена') IS NOT NULL THEN answer::numeric
            WHEN SUBSTRING(question from 'Доля полки') IS NOT NULL THEN answer::numeric
          END
        ELSE 0.0
      END price,
      h_vector,
      event_local_date,
      channel,
      iformat,
      company_name,
      network_name,
      signboard_name,
      client_category
    SQL

    data_source_3 = self.select(outer_selected_fields).from(Arel.sql("(#{data_source_2.to_sql}) as d2"))

    finish_selected_fields = <<-SQL

      ROW_NUMBER() OVER() id,
      (scid) edge_id,
      *,
      CURRENT_TIMESTAMP created_at

    SQL
    self.select(finish_selected_fields).from(Arel.sql("(#{data_source_3.to_sql}) as d3"))
  end

  def self.update_dimensions
    Channel.reload_rows
    ClientCategory.reload_rows
    SignboardName.reload_rows
    Question.reload_rows
  end

end

