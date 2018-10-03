#encoding:utf-8
class Photo < ApplicationRecord
  alias_attribute :visit_id, :checkin_id

  COMMON_IMAGE_OPTIONS =
    { styles:
      {
        original:
          {
            geometry: '10000x10000>',
            convert_options: '-auto-orient'
          },
        large_square: '200x200#'
      }
    }

  IMAGE_CONTENT_VALIDATOR =
    {
      content_type: /^image\/(jpg|jpeg|pjpeg|png|x-png|gif)$/,
      message: I18n.t('models.photo.unsupported_type_file')
    }

  CHECKIN_STARTED_DATE     = "(checkins.completed_at AT TIME ZONE 'UTC' AT TIME ZONE checkins.timezone)"

  has_attached_file :image,     COMMON_IMAGE_OPTIONS.merge(default_url: "/missing_images/:style/missing.png")
  has_attached_file :aws_image, COMMON_IMAGE_OPTIONS.merge(Rails.configuration.aws_options)
  process_in_background :image, queue: :paperclip

  belongs_to :question
  belongs_to :checkin, counter_cache: true
  belongs_to :report, counter_cache: true

  validates :checkin_id, presence: true
  validates :image, presence: true, if: lambda{|i| i.aws_image.blank?}
  validates :aws_image, presence: true, if: lambda{|i| i.image.blank?}

  validates_attachment_content_type :image, IMAGE_CONTENT_VALIDATOR
  validates_attachment_content_type :aws_image, IMAGE_CONTENT_VALIDATOR

  scope :with_dependencies, -> {
    joins(<<~SQL
        INNER JOIN checkins                 ON checkins.id                = photos.checkin_id
        LEFT JOIN reports                  ON reports.id                 = photos.report_id
        INNER JOIN users                    ON users.id                   = checkins.user_id
        INNER JOIN locations                ON locations.id               = checkins.location_id
        LEFT JOIN location_types           ON locations.location_type_id = location_types.id
        INNER JOIN LATERAL(
          SELECT user_versions.h_vector FROM user_versions
          WHERE user_versions.item_id = users.id
          AND user_versions.created_at < checkins.completed_at
          ORDER BY created_at DESC
          LIMIT 1
        ) t on true
      SQL
    )
  }

  scope :date_from,           ->(started_date_from) { where("#{CHECKIN_STARTED_DATE} >= ?", started_date_from) }
  scope :date_till,           ->(started_date_till) { where("#{CHECKIN_STARTED_DATE} <= ?", started_date_till.to_date.end_of_day.to_s) }
  scope :location_type_id,    ->(location_type_id) { where('locations.location_type_id IN (?)', location_type_id) }
  scope :business_id,         ->(business_id){ where('users.business_id = ?', business_id) }
  scope :chief_id,            ->(chief_id){ where('t.h_vector @> ?', chief_id.to_s) }
  scope :location_ids,        ->(location_ids) { where('locations.id IN (?)', location_ids) }
  scope :aws_uploaded,        -> { where.not(aws_image_file_name: nil) }
  scope :question_linked,     -> { where.not(question_id: nil) }
  scope :question_not_linked, -> { where(question_id: nil) }

  scope :company_ids,      ->(company_ids) { where('locations.company_id IN (?)', company_ids) }
  scope :signboard_ids,    ->(signboard_ids) { where('locations.signboard_id IN (?)', signboard_ids) }
  scope :organization_ids, ->(organization_ids) { where('users.organization_id IN (?)', organization_ids) }
  scope :checkin_type_ids, ->(checkin_type_ids) { where('reports.checkin_type_id IN (?)', checkin_type_ids) }

  scope_accessible :date_from, :date_till, :location_type_id, :business_id, :chief_id,
                   :location_ids, :signboard_ids, :company_ids, :organization_ids, :checkin_type_ids

  def queue_upload_to_s3
    Rails.configuration.aws_uploader.perform_async(self.id, self.checkin_id)
  end

  def self.filtered(filters = {})
    filters = HashWithIndifferentAccess.new(filters)

    select_sql = <<-SQL.strip.gsub(':checkin_started_date', CHECKIN_STARTED_DATE)
      REPLACE(locations.external_id, '*', '#') AS external_id,
      :checkin_started_date AS started_date,
      users.business_id,
      checkins.timezone,
      photos.*
    SQL

    self.with_dependencies.
    select(select_sql).
    periscope(filters).
    limit(filters[:limit])
  end

  def aws_path
    (aws_image.exists? ? aws_image : image).path&.gsub(/\?.*|\A\/|.*\/system\//,'')
  end
end
