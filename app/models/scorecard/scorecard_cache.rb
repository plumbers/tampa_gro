class ScorecardCache < ActiveRecord::Base
  self.skip_time_zone_conversion_for_attributes = [:event_local_date]

  after_initialize :set_state

  enum state: [:approved, :error]

  belongs_to :scorecard_job, foreign_key: :job_id, counter_cache: :scorecard_caches_count

  validates :event_type, presence: true
  validates :event_id, presence: true, numericality: true
  validates :event_local_date, presence: true

  scope :with_errors, ->{ self.where(:event_error.not_eq => nil) }
  scope :only_new_cache,    ->{ where("scorecard_caches.id > (SELECT COALESCE(MAX(edge_id),0) FROM scorecard_histogram)") }
  scope :requester,       ->(user_id){ where("h_vector @> '?'", user_id) }

  def set_state
    self.state = :approved unless self.state
  end

end
