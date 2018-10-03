# == Schema Information
#
# Table name: uploads
#
#  id                :integer          not null, primary key
#  type              :string(255)      not null
#  user_id           :integer          not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  file_file_name    :string(255)
#  file_content_type :string(255)
#  file_file_size    :integer
#  file_updated_at   :datetime
#  status_id         :integer          default(0), not null
#  failed_rows       :text
#  rows_total        :integer
#  percent           :float
#  status            :integer
#  upload_errors     :jsonb
#  options           :jsonb
#  state             :string
#
# Indexes
#
#  index_uploads_on_user_id  (user_id)
#

class LogUpload < Upload

  MAX_FILE_SIZE = 15.megabytes

  belongs_to :user, class_name: 'UserUnscoped', foreign_key: 'user_id'

  jsonb_accessor :options, encryption_key_version: :string
  validates :encryption_key_version, presence: true
  validates_attachment_size :file, less_than: ->(record){ record.class::MAX_FILE_SIZE }

  def file_uri
    file.url
  end

  def created_date
    @created_date ||= created_at.to_date
  end

  def max_file_size
    15.megabytes
  end


end
