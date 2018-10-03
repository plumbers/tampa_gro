class ScorecardGeneratorJob < ActiveJob::Base
  queue_as :scorecard_generator_jobs

  rescue_from(StandardError) do |exception|
    Rollbar.error(exception)
  end

  def perform(job_id)
    @object   = ScorecardJob.find job_id

    @object.reset!
    @object.restart!

    generator = Scorecard::Generator.new scorecard_top_id: @object.scorecard_top_id, scorecard_date: @object.scorecard_date, object: @object

    if generator.process
      args = {status: :finished}
    else
      args = {status: :error }
    end

    @object.update! args.merge errors_count: @object.scorecard_caches.with_errors.count, job_errors: generator.saved_errors.full_messages
  end

end
