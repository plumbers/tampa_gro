class FcmToken < ApplicationRecord
  FIREBASE_TTL = 3.days.ago.freeze

  belongs_to :user

  scope :active, -> { where(revoked_at: nil) }
  scope :with_token, ->(token) { where(key: token) }
  scope :recent, ->() { active.where(created_at: FIREBASE_TTL..Time.now) }

end
