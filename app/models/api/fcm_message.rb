class FcmMessage < ApplicationRecord
  DEFAULT_EXPIRATION_PERIOD = 3.days.freeze

  MSG = {
          title: :string,
          body: :string,
          icon: :string
  }

  jsonb_accessor  :msg,
                  notification: MSG,
                  data: MSG

  jsonb_accessor  :options,
                  collapse_key: :string,
                  content_available: :string,
                  priority: :boolean

  jsonb_accessor  :origin,
                  origin_id: :integer,
                  origin_type: :string

  jsonb_accessor  :target,
                  location_ids: :integer_array,
                  location_ext_id: :string

  jsonb_accessor  :send_timestamps,
                  tm_last: :date_time,
                  tm_all: :date_time_array

  jsonb_accessor  :ack_timestamps,
                  tm_all: :date_time_array,
                  user_id: :integer_array

  jsonb_accessor  :recipients,
                  user_ids: :integer_array,
                  device_tokens: :string_array,
                  descendants_ids: :integer_array,
                  users_ids_with_plan: :integer_array,
                  users_ids_in_locations: :integer_array

  after_initialize :set_defaults, if: :new_record?

  belongs_to :author, class_name: :User, foreign_key: :author_id
  belongs_to :business
  belongs_to :organization

  private

  def set_defaults
    self.expired_at = Time.now - DEFAULT_EXPIRATION_PERIOD
  end
end
