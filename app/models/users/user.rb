#encoding:utf-8
class User < ActiveRecord::Base

  EMAIL_REGEXP        = /\A.+@.+\..+\z/
  NO_LEFT_MENU_PAGES  = [['checkins', 'edit'], ['checkins', 'edit_1_release'],
                         ['locations','nearby'],
                         ['users', 'set_profile'], ['users', 'update_profile'],
                         ['errors', 'exception'], ['errors', 'not_found']]
  ALLOWED_ROLES       = ['merchendiser', 'supervisor', 'teamlead', 'trade_person', 'content_manager', 'regional_manager', 'manager', 'executive', 'director', 'head_manager', 'ceo', 'president']
  MOBILE_PHONE_REGEXP = /\A\+(\d){11,16}\z/

  #serialize :agreement_versions, JSON # Rails 4.1 hack for JSONB

  # NOTE: we need this cause of devise validation problem (does not take deleted_at in count)
  # ask Vadim Usmanov for details
  def self.validates_uniqueness_of(*attr_names)
    if [:email, :mobile_phone].include?(attr_names[0]) and (attr_names[1] || {})[:scope] != :deleted_at
      validates_uniqueness_of attr_names[0], attr_names[1].merge({scope: :deleted_at})
    else
      super *attr_names
    end
  end

  attr_accessor :email_or_phone, :notify_by_sms

  include UserModulesAndCallbacks

  validates_uniqueness_of :email, allow_blank: true, if: lambda{|i| i.email.present? && i.email_changed? }, scope: :deleted_at
  validates_format_of     :email, allow_blank: true, if: lambda{|i| i.email.present? && i.email_changed?},  with: EMAIL_REGEXP

  validates_presence_of     :password, if: :password_required?
  validates_confirmation_of :password, if: :password_required?
  #validates_presence_of     :personal_agreement, if: lambda{|i| i.role == 'teamlead'}, on: :create
  validates_length_of       :password, within: 8..72, allow_blank: true
  validates                 :organization, presence: true, if: lambda{|i| %w(teamlead supervisor merchendiser).include?(i.role) }
  validates                 :route_id, presence: true, allow_nil: true, if: lambda{|i| i.role == 'merchendiser' }
  validate                  :route_id_uniqueness, if: lambda{|i| i.role == 'merchendiser' && i.route_id && i.organization_id }
  # validate                  :supervisor_is_supervisor, if: ->(u){u.role == 'merchendiser'}
  
  attr_accessor :invite_role_name, :skip_name_validation, :skip_phone_validation, :dummy
  alias_method :dummy?, :dummy

  belongs_to :organization, touch: true
  # NOTE: не используется после того, как сняли кеширование вьюх со страницы /team
  # NOTE ; все равно должно быть актуально для страниц points_assigning/listing, points_assigning/mapping
  belongs_to :supervisor, :class_name => 'User', :foreign_key => 'supervisor_id'
  
  has_many :plan_items_as_inspector, :class_name => 'PlanItem', :foreign_key => 'inspector_id'
  has_many :plans_as_inspector, :class_name => 'Plan', :foreign_key => 'inspector_id'
  has_many :plan_items_as_inspector, :class_name => 'PlanItem', through: :plans_as_inspector, source: :plan_items
  has_many :locations
  has_many :checkins
  has_many :checkin_lites
  has_many :sent_messages, :class_name => 'Message', :foreign_key => :sender_id, :inverse_of => :sender
  has_many :received_messages, :class_name => 'Message', :foreign_key => :receiver_id, :inverse_of => :receiver
  has_many :supervised_users, :class_name => 'User', :foreign_key => 'supervisor_id'
  has_many :inspector_locations, -> { where :location_id.not_eq => nil }, :class_name => 'InspectorLocation', :foreign_key => 'inspector_id', :dependent => :destroy, :inverse_of => :inspector
  has_many :timetables
  has_many :api_keys, :inverse_of => :user
  has_many :lenta_items
  has_many :audit_templates
  has_many :user_histories
  has_many :week_schedules, dependent: :destroy
  has_many :week_schedule_versions
  has_many :route_locations, through: :week_schedules, source: :location

  has_many :invited_users, :class_name => 'User', :foreign_key => 'invited_by_id'
                             
  has_many :sku_uploads
  has_many :location_uploads
  has_many :ap_uploads
  has_many :exports
  has_many :ap_exports
  has_many :scorecard_exports
  has_many :sales_uploads
  has_many :sales_plan_uploads
  has_many :planogram_images

  #store :intro, coder: JSON

  has_and_belongs_to_many :inspected_places, :class_name => 'Location', :join_table => 'inspector_locations', :association_foreign_key => 'location_id', :foreign_key => 'inspector_id'

  accepts_nested_attributes_for :timetables, :allow_destroy => true
  accepts_nested_attributes_for :inspector_locations, :allow_destroy => true
  accepts_nested_attributes_for :organization

  validates :role, inclusion: {in: User::ALLOWED_ROLES }, allow_nil: false, allow_blank: false
 
  validates :mobile_phone, presence: true, allow_nil: false, allow_blank: false, unless: lambda{|x| x.skip_phone_validation}
  validates_format_of :mobile_phone, :with => MOBILE_PHONE_REGEXP, if: lambda{|x| x.mobile_phone.present?}
  
  #validates_uniqueness_of_without_deleted :mobile_phone, if: lambda{|x| x.mobile_phone.present?}
  validates :mobile_phone, uniqueness_without_deleted: true, if: lambda{|x| x.mobile_phone.present?}
  validates_presence_of :name, :unless => lambda{|i| i.skip_name_validation}

  ALLOWED_ROLES.each do |role|
    scope role.pluralize.to_sym, lambda{ where(role: role) }
  end
  scope :not_imported, lambda{ where(imported: [false, nil]) }
  scope :without_route, lambda{ includes(:inspector_locations).where(role: 'merchendiser', route_id: nil, inspector_locations: {inspector_id: nil}) }

  sanitize_parameters :name

  def group_ids
    if self.organization
      [self.organization.group_id]
    else
      Organization.where(id: self.organization_ids).pluck(:group_id).uniq
    end
  end

  def lenta_descendants
    self.descendants.where(role: 'merchendiser')
  end

  def get_teamlead
    self.ancestors.where(role: 'teamlead').first
  end

  def agreement_versions
    super || {}
  end

  def unread_messages
    Message.received_by_user(self).unread  
  end

  def self.with_given_api_key api_key
    return nil unless api_key
    User.joins(:api_keys).where(:api_keys => {:expires_at.gt => Time.now,
                                              :auth_token => api_key}).first
  end

  def organization_ids
    if organization_id 
      orgs = [organization_id]
      orgs |= Organization.where(group_id: organization.group_id, is_tdm_org: false).pluck(:id) if is_tdm?
      orgs
    else 
      self.self_and_descendants.where(role: 'teamlead').pluck :organization_id
    end
  end

  def name_or_email
    self.name || self.mobile_phone || self.email
  end

  def name_with_organization
    org_name  = self.organization.try(:name)
    result    = self.name_or_email
    result    = result + " (#{org_name})" if org_name
  end

  def all_subordinates_with_self_query
    children_ids = self.self_and_descendant_ids.join(',')
    "users.id IN (#{children_ids})"
  end

  def paid_account?
    @paid ||= !!if chief?
                Organization.where(id: self.organization_ids).pluck(:paid_till).detect{|pt| !pt.try(:past?)}
              else
                self.organization.try(:subscribed?)
              end
  end

  alias_method(:payed_account?, :paid_account?)

  def free_account?
    not self.payed_account?
  end
  
  # --- ROLES DISCOVERING ---

  def merchendiser?
    self.role == 'merchendiser'
  end
  alias_method :merch?, :merchendiser?
  alias_method :merchandiser?, :merchendiser?

  def supervisor?
    self.role == 'supervisor'
  end
  alias_method :sv?, :supervisor?

  def trade_person?
    self.role == 'trade_person'
  end
  alias_method :tp?, :trade_person?

  def teamlead?
    self.role == 'teamlead'
  end
  alias_method :tl?, :teamlead?
  
  def officer?
    Role.officers.include? self.role
  end

  def rank?
    Role.ranks.include? self.role
  end

  def manager?
    self.role == "manager"
  end

  def admin?
    self.role == 'admin'
  end

  def content_manager?
    self.role == 'content_manager'
  end

  alias_method(:observer?, :content_manager?)
  alias_method(:confirmer?, :content_manager?)

  def api_role
    if self.supervisor?
      'sv'
    elsif self.rank?
      'merch'
    elsif self.teamlead? || self.chief?
      'chief'
    elsif self.trade_person?
      'trade_person'
    end
  end

  def author_api_role
    I18n.t "roles.#{UserUnscoped.where(id: self.id).first.api_role}"
  end

  def chief?
    ['president', 'ceo', 'head_manager', 'director', 'executive', 'regional_manager', 'manager'].include? self.role
  end

  def subordinates_not_using_system
    return @subordinates_not_using_system_ids if @subordinates_not_using_system_ids
    # subordinates
    # who never logged in mobile version
    # who have phone number and never logged in web version
    @subordinates_not_using_system_ids =
      self.descendants.
           where(mobile_login_count: 0).
           where(sign_in_count: 0, :mobile_phone.not_eq => nil).pluck(:id)
  end

  def subordinates_tree(root: self, exclude: nil)
    exclude = root if exclude.nil? && root != self
    hash = {id: root.id, role: root.role, name: root.name}
    if self.organization
      hash[:version] = self.organization.locations_version.to_s
    else
      exclusion = exclude.present? ? {:id.not_eq => exclude.id} : {}
      hash[:children] = self.children.where(exclusion).map do |child|
        child.subordinates_tree exclude: exclude
      end
    end
    hash
  end

  def json_tree(options = {}, ability)
    tree_scope = hash_tree_scope(options[:limit_depth])
    ancestors = self.ancestors.reverse
    tree_scope = ancestors + tree_scope
    
    tree = ActiveSupport::OrderedHash.new
    id_to_hash = {}
    json_hash = {}
    not_using_system = Set.new(self.subordinates_not_using_system)
  

    attributes_for = -> (ea) do
      attributes  = ea.attributes.slice("id", "name", "mobile_phone", "email", "name", "role", "supervisor_id", "route_id")
      abilities   = {"abilities" => {"rerole" => ability.can?(:rerole, ea),
                                     "replace" => ability.can?(:replace, ea),
                                     "reassign" => ability.can?(:reassign, ea),
                                     "add_chief" => ability.can?(:add_chief, ea),
                                     "show" => ability.can?(:show, ea),
                                     "timetable" => ability.can?(:timetable, ea),
                                     "destroy" => ability.can?(:destroy, ea),
                                     "reinvite" => ability.can?(:reinvite, ea),
                                     "watch_phone" => ability.can?(:watch_phone, ea),
                                     "add_subordinate_for" => ability.can?(:add_subordinate_for, ea),
                                     "add_trade_person" => ability.can?(:add_trade_person, ea)
                                    }
                    }
      attributes.merge!(abilities).merge!("is_active" => not_using_system.include?(ea.id) ? 0 : 1)
    end

    tree_scope.each do |ea|
      json_hash[ea.id] = attributes_for.call(ea)

      h = id_to_hash[ea.id] = ActiveSupport::OrderedHash.new
      if ea.root? || tree.empty? # We're at the top of the tree.
        tree[ea.id] = h
      else
        id_to_hash[ea._ct_parent_id][ea.id] = h
      end
    end
   
    return [json_hash, tree]
  end

  def self.find_for_database_authentication warden_conditions
    conditions  = warden_conditions.dup
    login_type, login = self.login_field_type conditions[:email_or_phone]

    return nil if login_type == :invalid

    self.find_by login_type => login
  end

  def self.login_field_type(login_field)
    login_field = login_field.to_s.downcase
    if login_field =~ EMAIL_REGEXP
      [:email, login_field]
    elsif login_field =~ MOBILE_PHONE_REGEXP
      [:mobile_phone, login_field.gsub(/[^0-9^\+]/, '')]
    else
      [:invalid, nil]
    end
  end

  def has_blank_fields?
    self.mobile_phone.blank? || self.name.blank?
  end

  def send_new_password!(sms_type:)
    new_password                = self.imported? ? '12345678' : SecureRandom.urlsafe_base64.gsub(/[\-_]/, '')[0..8]
    self.password               = new_password
    self.password_confirmation  = new_password
    self.save(validate: false)
    sender = SmsSender.new(client_type: Rails.application.config.sms_sender, sms_type: sms_type)
    sender.send_sms(receiver: self, new_password: new_password)
    self
  end

  def self.invite! params, inviter
    user = User.new(params)
    user.invite! inviter
  end

  def invite! inviter
    self.invited_by_id = inviter.id
    self.send_new_password!(sms_type: :invitation)
  end

  def is_tdm?
    self.supervisor? && self.organization.is_tdm_org?
  end

  # Checks whether a password is needed or not. For validations only.
  # Passwords are always required if it's a new record, or if the password
  # or confirmation are being set somewhere.
  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end

  # description: http://postgresql.ru.net/manual/queries-with.html
  def officer_descendant_ids_with_destroyed
    sql = <<-SQL
      SELECT u.id FROM
      (
      WITH RECURSIVE supervisors(id, supervisor_id) AS
            (SELECT id, supervisor_id FROM users WHERE supervisor_id = #{self.id}
             UNION
             SELECT  t.id, t.supervisor_id
             FROM    supervisors
             INNER JOIN users t
             ON      t.supervisor_id = supervisors.id) select id from supervisors
      )data
      INNER JOIN users u on u.id = data.id
      WHERE
      u.role = 'supervisor' OR u.role = 'teamlead'
    SQL
    [self.id] + ActiveRecord::Base.connection.execute(sql).map{|el| el['id'].to_i }
  end

  def scorecard_top_in_hierarchy?
    self.self_and_ancestors.pluck(:scorecard_top).any?
  end

  private

  def supervisor_is_supervisor
    errors.add :supervisor_id, 'only supervisor role is available for supervisor' unless self.supervisor.role == 'supervisor'
  end

  def route_id_uniqueness
    tdmness       = self.organization.is_tdm_org
    group_id      = self.organization.group_id

    duplicate_route_exists = User.joins(:organization).where(users: { route_id: self.route_id, :id.not_eq => self.id })
    duplicate_route_exists =
      if group_id
        tdm_condition = tdmness ? "IS TRUE" : "IS NOT TRUE"
        duplicate_route_exists.where(organizations: {group_id: group_id}).where("organizations.is_tdm_org #{tdm_condition}")
      else
        duplicate_route_exists.where(organizations: {id: self.organization_id})
      end

    errors.add( :route_id, :taken, org_type: (tdmness ? 'sales' : 'merch'), group_id: group_id ) if duplicate_route_exists.any?
  end
end
