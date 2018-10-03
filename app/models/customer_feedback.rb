class CustomerFeedback < ActiveRecord::Base
  #attr_accessible :email, :name, :text
  attr_accessor :fake_subject

  validates_presence_of :email, :name, :text
  validates_format_of :email, :with => User::EMAIL_REGEXP
  validates :fake_subject, absence: true

  after_save :send_email
  
  sanitize_parameters :email, :name, :text

  private
  def send_email
    #FeedbackMailJob.enqueue_in(15.seconds, email, name, text)
    mail = FeedbackMailer.send_feedback(email: email, name: name, text: text)
    mail.deliver_later
  end
end
