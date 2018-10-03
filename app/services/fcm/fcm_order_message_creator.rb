module Fcm
  class OrderMessageCreator

    attr_accessor :order, :msgr

    def initialize(order_id)
      @order = Order.find(order_id)
      @msgr = Fcm::Messenger.new(message_attrs)
    end
    
    def create_for
      msg_obj = msgr.produce_msg_object
      if msg_obj.save
        msgr.enqueue_message
      else
        Rails.logger.error msg_obj.errors
        msgr.update! errors_hash: { order_msg: msg_obj.errors }
      end
    end

    def message_attrs
      external_id, signboard_name = location_ext_id(order.location_id)
      {
        title: I18n.t('services.fcm.message_title', signboard_name: signboard_name, external_id: external_id),
        body: I18n.t('services.fcm.message_body', signboard_name: signboard_name, external_id: external_id,
                     order_content: order.content),
        origin: {
          origin_id: order.id,
          origin_type: 'Order'
        },
        target: {
          location_ids: order.location_id,
          location_ext_id: external_id
        },
        author_id: order.author_id
      }
    end

    def location_ext_id(location_id)
      Location.with_dependencies.
        where(id: location_id).
        pluck(:external_id, :'signboards.name').
        flatten
    end

  end
end
