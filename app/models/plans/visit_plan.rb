class VisitPlan < ApplicationRecord
  include EventBus::Model
  include EventBus::VisitPlanCallbacks
  include TimeInTimezone

  acts_as_paranoid

  attr_accessor :skip_uniqueness_validates

  CRITICAL_ATTRIBUTES = %i(user_id location_id thedate week_num day_num hash_key)

  belongs_to :user,     class_name: 'UserUnscoped'
  belongs_to :location, class_name: 'LocationUnscoped'
  belongs_to :user_version

  has_one :checkin, foreign_key: 'visit_plan_hash_key', primary_key: 'hash_key', inverse_of: :visit_plan

  enum state: { pending: 0, active: 1, finished: 2 }
  store_accessor :options, :planned_move_time, :planned_work_time, :merchendising_type, :agency_name

  validates :week_num,    numericality: true
  validates :day_num,     numericality: true
  validates :user_id,     presence: true
  validates :location_id, presence: true
  validates :timezone,    presence: true, exclusion: { in: %w(uninhabited) }

  with_options unless: -> { skip_uniqueness_validates.presence } do
    validates :thedate,  presence: true, uniqueness_without_deleted: { scope: [:user_id, :location_id] }
    validates :hash_key, presence: true, uniqueness_without_deleted: true
  end

  validates_with CriticalFieldsChangedValidator, attributes: CRITICAL_ATTRIBUTES, on: :update #NOTE: This should be before future validation
  validate :only_future_modifications_allowed, on: :update

  before_validation :set_thedate, if: -> { self.thedate.nil? && self.week_num && self.day_num }
  before_validation :set_week_and_day, if: -> { self.thedate.present? && (self.week_num.nil? || self.day_num.nil?) }
  before_validation :set_hash_key, on: :create, if: -> { self.hash_key.nil? }
  before_validation :set_user_version_id
  before_validation :set_timezone

  scope :for_inspector, -> (user) { where(user_id: user.id) }
  scope :for_day,       -> (date) { where(thedate: date, week_num: Date.week_num_of(date), day_num: date.cwday) }

  def set_thedate
    self.thedate = date_by_week_and_day_num
  end

  def set_hash_key
    if (%w(user_id location_id thedate) & self.changes.keys).any?
      self.hash_key = self.class.generate_hash_key(user_id, location_id, thedate)
    end
  end

  def self.generate_hash_key(uid, lid, date)
    XXhash.xxh64 [uid, lid, date].join
  end

  private

  def set_week_and_day
    self.week_num = Date.week_num_of(thedate)
    self.day_num  = thedate.cwday
  end

  def only_future_modifications_allowed
    errors.add(:base, :past_visit_plan) if thedate < current_date
  end

  def set_user_version_id
    self.user_version_id ||= user.versions.order(:created_at).last&.id
  end

  def set_timezone
    self.timezone ||= location.timezone
  end

  def date_by_week_and_day_num
    days_passed         = (user.current_date - Date::START_POINT).to_i
    window_num          = days_passed / 28
    abs_day_in_a_window = days_passed % 28
    week_of_window      = abs_day_in_a_window / 7

    (window_num = window_num + 1) if is_in_past_of?(week_of_window)

    Date::START_POINT + ((window_num * 28) + day_num - week_num + ((week_num - 1)* 8)).days
  end

  def is_in_past_of?(week_of_window)
    previous_week = (week_num - 1) < week_of_window
    current_week  = (week_num - 1) == week_of_window
    previous_day  = day_num < user.current_date.cwday

    previous_week || (current_week && previous_day)
  end

end
