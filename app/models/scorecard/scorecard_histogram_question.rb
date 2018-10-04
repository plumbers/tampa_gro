class ScorecardHistogramQuestion < ActiveRecord::Base
  self.table_name  = 'scorecard_histogram_questions'

  def self.reload_rows requester_id
    existed_questions = self.select("DISTINCT question")
    new_questions = ScorecardHistogram.requester(requester_id).
                                        where("question NOT IN (?)", existed_questions).
                                        select("question, ARRAY_AGG(id) ids").
                                        group(:question)
    return if new_questions.empty?
    batch_import_records(self, new_questions)
  end

end

