require 'fcm_message_processor'

class FcmPushMsgWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, queue: :firebase_push_msg_jobs

  def perform(fcm_message_id)
    Fcm::MessageProcessor.new(fcm_message_id).send_messages
  end

end
