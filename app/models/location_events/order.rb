class Order < ApplicationRecord
  include AgencyName

  STATUSES = HashWithIndifferentAccess[ new: 0, success: 1, fail: 2 ]

  belongs_to :author, class_name: 'User'
  belongs_to :performer, class_name: 'User'
  belongs_to :checkin
  belongs_to :location, class_name: "LocationUnscoped"
  has_one :location_event, as: :subject

  after_create :create_event

  validates :status, inclusion: STATUSES.values

  def new?
    self.status == STATUSES[:new]
  end

  def human_status
    case status
    when 0 then 'new'
    when 1 then 'success'
    when 2 then 'fail'
    end
  end

  def performer_name
    @performer_name ||= if status == STATUSES[:new]
                          nil
                        else
                          agency_name(performer_id) || I18n.t('models.location_events.order.agency')
                        end
  end

  def performed_at
    updated_at unless status == STATUSES[:new]
  end

  def author_api_role
    I18n.t "roles.#{UserUnscoped.where(id: self.author).first.api_role}"
  end

  def author_role
    role, is_tdm_org = UserUnscoped.includes(:organization).where(id: self.author_id).pluck('users.role', 'organizations.is_tdm_org').first
    customized_role = if is_tdm_org
      case role
      when 'supervisor' then 'tdm'
      when 'teamlead' then 'teamlead-Sales'
      end
    else
      role
    end
    I18n.t("roles.#{customized_role}")
  end

  private

  def create_event
    self.create_location_event location: self.location
  end
end
