require 'fcm'
require 'fcm_message_processor'

module Fcm
  class Messenger < Valuable
    FcmError    = Class.new(StandardErrorWithI18n)
    FcmMsgError = FcmError.new

    has_value :title
    has_value :body
    has_value :origin
    has_value :target
    has_value :author_id

    attr_reader :author, :business_id, :organization_id, :recipients, :msg_object, :fcm
    
    def enqueue_message
      # FcmPushMsgWorker.perform_async(@msg_object.id)
      FcmPushMsgWorker.new.perform(@msg_object.id)
    end

    def produce_msg_object
      msg_attrs = {
        title: title,
        body: body
      }
      attrs = {
        data: msg_attrs,
        notification: msg_attrs,
        options: {
          collapse_key: "MSTlab24 #{target[:location_ext_id]}",
          content_available: true,
          priority: 'high'
        },
        recipients: {
          user_ids: all_users_in_target_locations,
          device_tokens: recipients_tokens,
          descendants_ids: recipients.pluck(:id),
          users_ids_with_plan: users_with_plan_in_locations,
          users_ids_in_locations: visitors_in_locations
        },
        target: {
            location_ext_id: target[:location_ext_id],
            location_ids: target_locations_ids
        },
        origin: origin,
        author_id: author_id,
        business_id: business_id,
        organization_id: organization_id,
        expired_at: Date.tomorrow.beginning_of_day
      }
      @msg_object = FcmMessage.new(attrs)
      @msg_object
    end

    def all_users_in_target_locations
      users_with_plan_in_locations + visitors_in_locations
    end

    def users_with_plan_in_locations
      VisitPlan.
        in_locations(target_locations_ids).
        where(thedate: Date.today, user_id: recipients.pluck(:id)).
        pluck(:user_id)
    end

    def visitors_in_locations
      Checkin.
        in_locations(target_locations_ids).
        not_finished.
        started_today.
        created_by(recipients.pluck(:id)).
        pluck(:user_id)
    end

    def target_locations
      @target_locations ||= Location.
          in_business(business_id).
          owned_by_organization(recipients.pluck(:organization_id)).
          where(external_id: target[:location_ext_id])
    end

    def target_locations_ids
      target_locations.pluck(:id)
    end

    def author
      @author ||= UserUnscoped.where(id: author_id).first
    end

    def business_id
      @business_id ||= author.business_id
    end

    def organization_id
      @organization_id ||= author.organization_id
    end

    def recipients
      return @recipients if defined? @recipients
      @recipients = author.descendants
    end

    def recipients_tokens
      @recipients_tokens ||= recipients.
        with_fcm_token(all_users_in_target_locations).
        map{ |u| u.fcm_tokens.recent.last[:key] }
    end

    def location_info
      target_locations.with_dependencies.map{ |l| "#{l[:'signboards.name']} #{l[:external_id]}" }.first
    end
  end

end
