# == Schema Information
#
# Table name: encryption_keys
#
#  id          :integer          not null, primary key
#  key_length  :integer
#  key_type    :string
#  random_key  :string
#  random_iv   :string
#  key_version :integer
#  user_id     :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_encryption_keys_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#

class EncryptionKey < ApplicationRecord
  # 128-bit, bc Android under SDK v18 natively supports 16-bytes encryption key length only
  DEFAULT_OPTS = { key: { length: 128, type: :CBC }, expiration_period: 90.days.to_i }.freeze

  has_paper_trail ignore: [:created_at, :updated_at, :user_id, :id],
                  on: [:update, :create],
                  class_name: 'EncryptionKeyVersion'

  belongs_to :user, class_name: 'UserUnscoped'

  validates :user_id, presence: true

  after_initialize :create_key, if: :new_record?

  def regenerate!
    create_key
    save!
  end

  def invoke_key_by(version = self.key_version)
    invoke_version(version)
  end

  def event
    @event ||= if self.versions.count.zero?
                 :create
               else
                 :update
               end
  end

  def current_version
    return @current_version if defined?(@current_version)
    @current_version = versions.order(:created_at).last
  end

  private

  def cipher
    @cipher ||= OpenSSL::Cipher::AES.new(key_length, key_type)
  end

  def update_encryption_settings
    self.key_version = (Time.now.to_f*1000).to_i
    self.key_length, self.key_type = business_settings
  end

  def create_key
    update_encryption_settings
    self.random_key = cipher.random_key.unpack('H*')[0]
    self.random_iv  = cipher.random_iv.unpack('H*')[0]
  end

  def invoke_version(version)
    if version.present?
      paper_trail.version_at(timestamp version)
    else
      self
    end
  end

  def business_settings
    enc_key = user&.business&.encryption.try(:[], :key).presence || DEFAULT_OPTS[:key]
    [ enc_key[:length], enc_key[:type] ]
  end

  def business_expiration_period
    user&.business&.encryption&.expiration_period || DEFAULT_OPTS[:expiration_period]
  end

  def timestamp(version)
    Time.at(version)+1
    #+1 bc paper_trail.version_at(timestamp) E (time1, time2], (time3, time4]
    # in other words - not included started timestamp of interval, in which this version is valid
    # so we should skip right after time2, for reach actual version
  end

end
