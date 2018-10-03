require 'fcm_order_message_creator'

class OrderSubscriber

  def order_after_create(order_record)
    Fcm::OrderMessageCreator.new(order_record.id).create_for
  end

end
