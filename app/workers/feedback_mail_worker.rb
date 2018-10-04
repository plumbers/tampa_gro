class FeedbackMailWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, queue: :feedback_mail

  def perform(email, name, text)
    FeedbackMailer.send_feedback(email: email, name: name, text: text)
  end

end
