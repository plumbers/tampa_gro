require 'periscope-activerecord'

class ScorecardHistogramFact < ActiveRecord::Base
  self.primary_key = 'id'
  self.table_name  = 'scorecard_histogram_facts'

  scope :in_period,       ->(start_date, end_date){ where("event_local_date BETWEEN ? AND ?", start_date, end_date) }
  scope :requester,       ->(user_id){ where("h_vector @> '?'", user_id) }

  scope :network_name,      ->(network_names){ where("network_name_id IN (?)", network_names) }
  scope :signboard_name,    ->(signboard_names){ where("signboard_name_id IN (?)", signboard_names) }
  scope :channel,           ->(channels){ where("channel_id IN (?)", channels) }
  scope :iformat,           ->(iformats){ where("iformat_id IN (?)", iformats) }
  scope :client_category,   ->(client_categories){ where("client_category_id IN (?)", client_categories) }

  ScorecardHistogramsController::FILTER_FIELDS.each do |filter|
    scope_accessible filter.to_sym,           method: filter.to_sym
    scope_accessible "#{filter}_base".to_sym, method: filter.to_sym
  end

  scope_accessible :requester,      method: :requester
  scope_accessible :requester_base, method: :requester

  def self.reload_rows requester_id, current_edge_id
    scorecard_histogram_data = ScorecardHistogram.where("id > ?", current_edge_id).
                               requester(requester_id).
                               select(
                                " h_vector,
                                  event_local_date,
                                  ARRAY_AGG(q.id) question_ids,
                                  ch.id channel_id,
                                  if.id iformat_id,
                                  cn.id company_name_id,
                                  nn.id network_name_id,
                                  sn.id signboard_name_id,
                                  cc.id client_category_id").
                          joins("INNER JOIN scorecard_histogram_questions q ON scorecard_histogram.id=ANY(q.ids)").
                          joins("INNER JOIN channels ch                     ON ch.channel=scorecard_histogram.channel").
                          joins("INNER JOIN iformats if                     ON if.iformat=scorecard_histogram.iformat").
                          joins("INNER JOIN company_names cn                ON cn.company_name=scorecard_histogram.company_name").
                          joins("INNER JOIN network_names nn                ON nn.network_name=scorecard_histogram.network_name").
                          joins("INNER JOIN signboard_names sn              ON sn.signboard_name=scorecard_histogram.signboard_name").
                          joins("INNER JOIN client_categories cc            ON cc.client_category=scorecard_histogram.client_category").
                          group("h_vector, event_local_date, ch.id, if.id, cn.id, nn.id, sn.id, cc.id")

    return if scorecard_histogram_data.empty?
    batch_import_records(self, scorecard_histogram_data)
  end

end