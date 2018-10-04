class ScorecardHistogramTransformationWorker
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: :scorecard_histogram_transformation_jobs

  def perform scorecard_top_id
    ScorecardDaily.reload_rows scorecard_top_id
  rescue Exception=>e
    Rails.logger.error e
    puts e
  end

end