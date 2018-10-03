class Checkin < ApplicationRecord
  include EventBus::Model
  include EventBus::VisitCallbacks

  alias_attribute :audited_visit_id, :audited_checkin_id

  attr_readonly :cloud_photos_count, :received_photos_count
  attr_accessor :token_id, :creator_user_version

  has_one :report, -> { joins(:checkin_type_including_deleted).where(checkin_types: { role: 'task' }) }, dependent: :destroy
  belongs_to :user_version

  has_many :photos

  belongs_to :organization
  belongs_to :audited_checkin, class_name: 'Checkin'
  belongs_to :location
  belongs_to :location_including_deleted, :class_name => 'LocationUnscoped', :foreign_key => 'location_id'
  belongs_to :user, :class_name => 'UserUnscoped', :foreign_key => 'user_id'
  belongs_to :creator, class_name: 'UserUnscoped'
  belongs_to :checkin_type
  belongs_to :checkin_type_including_deleted, class_name: 'CheckinTypeUnscoped', foreign_key: 'checkin_type_id'
  belongs_to :api_key
  belongs_to :api_session
  belongs_to :visit_plan, foreign_key: 'visit_plan_hash_key', primary_key: 'hash_key', inverse_of: :checkin

  has_many :reports, dependent: :destroy, validate: false

  has_one :lenta_item, dependent: :destroy
  has_many :audit_checkins, dependent: :nullify, foreign_key: 'audited_checkin_id', class_name: 'Checkin'

  validates_presence_of :user_id
  validates_presence_of :location_id
  validates_presence_of :started_at, :started_date
  validates_presence_of :lat, :long, if: :finished_at?
  validates :mobile_api, inclusion: { in: Rails.configuration.api_versions }, allow_nil: false,
            if: :finished_at?
  validates :mobile_expected_photos_count, numericality: { greater_than_or_equal_to: 0 },
            allow_nil: false
  validates :first_visit_time, presence: true, if: :second_visit?,
            numericality: { greater_than_or_equal_to: 0, only_interger: true }

  validates_with NearEnoughToLocationValidator, if: -> do
    self.lat && self.long && self.location
  end

  validates :reports, length: { minimum: 1 }, if: :finished_at?
  validates_with VisitReportsValidator

  # NOTE: we do not check started_at/finished_at < Time.now
  validate :was_finished_after_was_started, if: ->  { self.started_at && self.finished_at }

  before_validation :deny_set_checkin_type_id_and_evaluations

  before_validation :set_second_visit, if: -> (checkin) do
    checkin.mobile_api.present? && checkin.mobile_api > 7 && checkin.paused_at.present?
  end

  scope :finished, -> { where.not(finished_at: nil) }

  def planned_data_set?
    planned_work_time || planned_move_time
  end

  def fi_checkin?
    reports.joins(:checkin_type_including_deleted).
            where(checkin_types: { legacy: true, name: 'PEPSI-KNOCK-KNOCK' }).count == 1
  end

  def allowed_questionaries_ids
    return @allowed_questionaries_ids if defined?(@allowed_questionaries_ids)

    ability = ApiCheckinAbility.new(user, mobile_api)
    @allowed_questionaries_ids = CheckinTypeMatcher.new(user, ability).get_allowed_questionaries_ids
  end

  def set_visit_plan_hash_key
    self.visit_plan_hash_key =
      VisitPlan.generate_hash_key(get_actual_user_id, location_id, started_date)
  end

  private

  def get_actual_user_id
    return user_id if creator_id.nil?

    if creator.name == user.name && creator.mobile_phone == user.mobile_phone
      user_id
    else
      creator_id
    end
  end

  def deny_set_checkin_type_id_and_evaluations
    if (checkin_type_id_changed? && checkin_type_id.present?) ||
       (evaluations_changed? && evaluations.present?)
      raise StandardError, 'You cannot set checkin#checkin_type_id and checkin#evaluations'
    end
  end

  def was_finished_after_was_started
    if self.finished_at < self.started_at
      errors.add(:base, I18n.t('models.checkins.checkin.not_complete_report_before'))
    end
  end

  def set_second_visit
    self.second_visit = true if second_visit.blank?
    self.first_visit_time = ((paused_at - started_at) / 60).ceil if first_visit_time.blank?
    self.first_visit_started_at = started_at if first_visit_started_at.blank?
  end
end
