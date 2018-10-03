module Fcm
  class MessageProcessor
    MAX_USER_IDS_PER_CALL = 50.freeze

    attr_reader :msg_object, :fcm

    def initialize(fcm_message_id)
      @msg_object = FcmMessage.find(fcm_message_id)
      @fcm = FCM.new(Rails.application.secrets.fcm_api_key)
    end

    def send_messages
      response = if any_device_tokens?
                   send_push
                 else
                   { send_error: "There is no any device tokens" }
                 end
    rescue => e
      Rails.logger.info "error in FcmMessage.new.save: #{e}"
    ensure
      Rails.logger.info response
    end

    private

    def send_push
      response = {}
      @msg_object.recipients['device_tokens'].each_slice(MAX_USER_IDS_PER_CALL) do |tokens|
        # response.merge("#{@msg_object.id}_#{Time.now.strftime('%S.%M.%H.%d.%m.%Y')}" => @fcm.send(tokens, construct_msg))
        response.merge("#{@msg_object.id}_#{Time.now.strftime('%S.%M.%H.%d.%m.%Y')}" => "@fcm.send(#{tokens}, #{construct_msg})")
      end
    rescue => e
      @msg_object.update! errors_hash: { send_error: e }
    ensure
      response
    end

    def any_device_tokens?
      !!@msg_object&.recipients.try(:[],'device_tokens')&.presence
    end

    def set_timestamp
      time_now = Time.now
      ts = @msg_object.send_timestamps
      ts = { tm_all: [] } if ts.nil?
      ts[:tm_last] = time_now
      ts[:tm_all] << time_now
      @msg_object.save!
    end

    def construct_msg
      return @construct_msg if defined? @construct_msg
      @construct_msg = @msg_object.options
      @construct_msg[:notification] = @msg_object.notification
      @construct_msg[:data]         = @msg_object.data
      @construct_msg
    end

  end
end
