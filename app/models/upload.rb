#encoding:utf-8
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

class Upload < ApplicationRecord
  OPTIONS_CRITICAL_KEYS = %w()

  CONTENT_TYPES = %w(
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/zip
    application/octet-stream
  )

  STATUSES = { 0 => :not_started, 1 => :in_progress, 2 => :finished, 3 => :error, 4 => :deleted }

  COMMON_CONTENT_TYPES = ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                          'application/zip',
                          'application/octet-stream'].freeze

  COMMON_FILE_NAME = [/\.xlsx\Z/, /\.zip\Z/].freeze

  enum status: [:not_started, :in_progress, :finished, :error, :deleted]

  has_paper_trail class_name: 'UploadVersion', meta: { file: :file_if_changed? },
    if: -> (o) { o.should_create_new_version? }

  has_attached_file :file

  validates_presence_of :type, :user_id
  validates_presence_of :file
  validates_attachment :file, content_type: { content_type: COMMON_CONTENT_TYPES + content_types },
                       file_name: { matches: COMMON_FILE_NAME + file_name_pattern }

  belongs_to :user, class_name: 'UserUnscoped'

  #TODO: Interface to reimplement in subclasses
  def self.content_types
    []
  end

  def self.file_name_pattern
    []
  end

  store :failed_rows, coder: YAML

  def status
    super.to_s.presence || old_status.to_s
  end

  def old_status
    STATUSES[self.status_id]
  end

  def percentage
    self.percent
  end

  def created_by_content_manager?
    user.content_manager?
  end

  def should_create_new_version?
    (saved_changes.keys & %w(state file_updated_at)).any? ||
      (options_changed_keys & self.class::OPTIONS_CRITICAL_KEYS).any?
  end

  private

  def options_changed_keys
    (options_before_last_save || {})
      .merge(options) { |k, o, n| [o, n] }
      .select { |k, (o, n)| o != n }.keys
  end

  def file_if_changed?
    return file if saved_change_to_file_updated_at?
  end
end
