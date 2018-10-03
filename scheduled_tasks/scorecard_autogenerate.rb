class ScorecardAutogenerate < Scheduler::SchedulerTask

  environments (Rails.configuration.scorecard_autogenerate ? Rails.env : :environment_is_not_exists)

  cron '10 0 * * *' #00:00-06:00 - silent hours - for avoid db locks during backup && shrink backup file

  def run
    scorecard_tops = User.where(scorecard_top: true)
    Rails.logger.info "Found #{scorecard_tops.count} scorecard users, processing.."
    scorecard_tops.each do |user|
      job = ScorecardJob.create! scorecard_top_id: user.id, scorecard_date: Date.yesterday
      jid = ScorecardGeneratorJob.perform_later(job.id).job_id
      job.update! jid: jid
    end
  rescue => e
    Rails.logger.info e
    Rollbar.error(e)
  end

end
