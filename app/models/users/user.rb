class User < ApplicationRecord

  acts_as_user

  NO_LEFT_MENU_PAGES = [['checkins', 'edit'], ['checkins', 'edit_1_release'],
                        ['locations', 'nearby'],
                        ['users', 'set_profile'], ['users', 'update_profile'],
                        ['errors', 'exception'], ['errors', 'not_found']]
  ALLOWED_ROLES = %w(
    merchendiser supervisor teamlead trade_person content_manager regional_manager
    manager executive director head_manager ceo president operator coordinator client custom
  ).freeze

  attr_accessor :email_or_phone, :notify_by_sms

  # NOTE: The order how modules are included - MATTERS!
  include PersistentModel
  include TimeInTimezone
  include UserModules::Authentication
  include UserModules::DeviseOverrides
  include UserModules::SubordinatesMaintenance
  include UserModules::Hierarchy
  include UserModules::Versioning
  include UserModules::VersionsMaintenance
  include UserModules::Passwords
  include DeferredCleanup
  include UserBusiness

  validates :organization, presence: true, if: -> (user) { %w(teamlead supervisor merchendiser).include?(user.role) }
  validates :route_id, presence: true, allow_nil: true, if: -> (user) { user.merchendiser? }
  validate  :route_id_uniqueness,  if: -> (user) { user.merchendiser? && user.route_id }

  attr_accessor :invite_role_name, :skip_name_validation, :dummy
  alias_method :dummy?, :dummy

  belongs_to :organization
  belongs_to :supervisor, class_name: 'User', foreign_key: 'supervisor_id'
  belongs_to :user_group
  belongs_to :rank

  has_many :visit_plans
  has_many :locations, ->{ uniq }, through: :visit_plans
  has_many :checkins
  has_many :supervised_users, class_name: 'User', foreign_key: 'supervisor_id'
  has_many :inspector_locations, -> { where.not(location_id: nil) }, class_name: 'InspectorLocation',
           foreign_key: 'inspector_id', inverse_of: :inspector
  has_many :api_keys, inverse_of: :user
  has_many :lenta_items

  has_many :invited_users, class_name: 'User', foreign_key: 'invited_by_id'

  has_many :location_uploads
  has_many :ap_uploads
  has_many :exports
  has_many :ap_exports
  has_many :photo_exports
  has_many :scorecard_exports
  has_many :location_events_exports
  has_many :kpi_uploads
  has_many :kpi_templates, through: :business
  has_many :planogram_images

  has_many :inspected_places, through: :inspector_locations, class_name: 'Location', foreign_key: 'inspector_id',
           source: :location

  has_many :calendars
  has_many :api_sessions
  has_many :access_tokens, class_name: '::Doorkeeper::AccessToken', foreign_key: 'resource_owner_id'
  has_one  :encryption_key

  has_one :email_replica
  has_one :admin_business, class_name: 'Business', dependent: :restrict_with_error, foreign_key: :admin_id

  has_many :client_contracts, inverse_of: :user, dependent: :destroy
  has_many :contracts, through: :client_contracts

  has_settings do |s|
    s.key :nearby_map, defaults: Location::NEARBY_DEFAULT
  end

  accepts_nested_attributes_for :inspector_locations, allow_destroy: true
  accepts_nested_attributes_for :organization
  accepts_nested_attributes_for :client_contracts

  validates :role, inclusion: { in: User::ALLOWED_ROLES }, allow_nil: false, allow_blank: false

  validates_presence_of :name, unless: -> (user) { user.skip_name_validation }
  validates :timezone, presence: true, exclusion: { in: %w(uninhabited) }, if: -> (user) { %w(merchendiser supervisor).include? user.role }

  ALLOWED_ROLES.each do |role|
    scope role.pluralize.to_sym, -> { where(role: role) }

    define_method "#{role}?" do
      self.role == role.to_s
    end
  end

  scope :not_imported, -> { where(imported: [false, nil]) }
  scope :without_route, -> do
    includes(:inspector_locations).
      merchendisers.
      where(route_id: nil, inspector_locations: { inspector_id: nil })
  end

  sanitize_parameters :name

  after_initialize :create_encryption_key, if: :new_record?

  def group_ids
    if self.organization
      [self.organization.group_id]
    else
      Organization.where(id: self.organization_ids).pluck(:group_id).uniq
    end
  end

  def lenta_descendants
    self.descendants.merchendisers
  end

  def get_teamlead
    self.supervisor.teamlead? ? self.supervisor : self.supervisor.supervisor rescue nil
  end

  def get_timezone
    self.timezone || self.self_and_ancestors.where.not(timezone: [nil, 'uninhabited']).limit(1).pluck(:timezone).first
  end

  def agreement_versions
    super || {}
  end

  def self.with_given_api_key api_key
    return nil unless api_key
    User.joins(:api_keys).where('api_keys.expires_at > ?', Time.now).
      where(api_keys: { auth_token: api_key }).take
  end

  def organization_ids
    return @organization_ids if defined?(@organization_ids)

    @organization_ids =
        if organization_id
          ids = [organization_id]
          ids |= Organization.where(group_id: organization.group_id, is_tdm_org: false).pluck(:id) if is_tdm?
          ids
        else
          Rails.cache.fetch("organization_ids_#{self.id}", expires_in: 2.hours) do
            ids = self_and_descendants.where(role: 'teamlead').pluck :organization_id
            ids |= Organization.where(is_tdm_org: false).
                joins('INNER JOIN organizations orgs on orgs.group_id = organizations.group_id').
                where(orgs: { id: ids, is_tdm_org: true }).
                pluck(:id)
            ids
          end
        end
  end

  def org_ids_in_all_time
    self_with_history.map(&:org_ids_with_history).flatten
  end

  def self_with_history
    UserUnscoped.where(mobile_phone: self.mobile_phone)
  end

  def org_ids_with_history
    [self.organization_id].push(org_ids_from_versions).flatten.compact.uniq
  end

  def org_ids_from_versions
    versions&.map{ |v| v.object.try(:[],"organization_id") ||
      v.object_changes.try(:[],"organization_id") }.flatten.compact
  end

  def events_org_ids
    return @events_org_ids if defined?(@events_org_ids)

    @events_org_ids =
      if organization_id
        ids = [organization_id]
        ids |= Organization.where(group_id: organization.group_id, is_tdm_org: false).pluck(:id) if is_tdm?
        ids
      else
        org_ids   = self_and_descendants.where(role: 'teamlead').pluck :organization_id
        group_ids = Organization.where(id: org_ids).pluck :group_id
        org_ids  |= Organization.where(group_id: group_ids).pluck :id
        org_ids
      end
  end

  def name_or_email
    self.name || self.mobile_phone || self.email
  end

  def name_with_organization
    org_name = self.organization.try(:name)
    result = self.name_or_email
    result = result + " (#{org_name})" if org_name
  end

  def all_subordinates_with_self_query
    children_ids = self.self_and_descendant_ids.join(',')
    "users.id IN (#{children_ids})"
  end

  def paid_account?
    true
  end

  alias_method(:payed_account?, :paid_account?)

  def free_account?
    false
  end

  # --- ROLES DISCOVERING ---

  alias_method :merch?, :merchendiser?
  alias_method :merchandiser?, :merchendiser?

  alias_method :sv?, :supervisor?

  alias_method :tp?, :trade_person?

  alias_method :tl?, :teamlead?

  alias_method :observer?, :content_manager?
  alias_method :confirmer?, :content_manager?

  def officer?
    Role.officers.include? self.role
  end

  def rank?
    Role.ranks.include? self.role
  end

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
    Role.chiefs.include? self.role
  end

  def subordinates_not_using_system
    return @subordinates_not_using_system_ids if @subordinates_not_using_system_ids
    # subordinates
    # who never logged in mobile version
    # who have phone number and never logged in web version
    @subordinates_not_using_system_ids =
      self.descendants.
        where(mobile_login_count: 0, sign_in_count: 0).
        where.not(mobile_phone: nil).
        pluck(:id)
  end

  def subordinates_tree(root: self, exclude: nil)
    exclude = root if exclude.nil? && root != self
    hash = { id: root.id, role: root.role, name: root.name }
    if self.organization
      hash[:version] = self.organization.locations_version.to_s
    else
      childrens_scope = exclude.present? ? children.where.not(id: exclude.id) : children

      hash[:children] = childrens_scope.map do |child|
        child.subordinates_tree(exclude: exclude)
      end
    end
    hash
  end

  def json_tree(options = {}, ability)
    tree_scope = self.class._ct.default_tree_scope(self_and_descendants, options[:limit_depth])
    ancestors  = self.ancestors.reverse
    tree_scope = ancestors + tree_scope

    tree = ActiveSupport::OrderedHash.new
    id_to_hash = {}
    json_hash = {}
    not_using_system = Set.new(self.subordinates_not_using_system)


    attributes_for = -> (ea) do
      attributes = ea.attributes.slice('id', 'name', 'mobile_phone', 'email', 'name', 'role', 'supervisor_id',
                                       'route_id')
      abilities = { 'abilities' => { 'rerole' => ability.can?(:rerole, ea),
                                     'replace' => ability.can?(:replace, ea),
                                     'reassign' => ability.can?(:reassign, ea),
                                     'add_chief' => ability.can?(:add_chief, ea),
                                     'show' => ability.can?(:show, ea),
                                     'timetable' => ability.can?(:timetable, ea),
                                     'destroy' => ability.can?(:destroy, ea),
                                     'reinvite' => ability.can?(:reinvite, ea),
                                     'watch_phone' => ability.can?(:watch_phone, ea),
                                     'add_subordinate_for' => ability.can?(:add_subordinate_for, ea),
                                     'add_trade_person' => ability.can?(:add_trade_person, ea)
      }
      }
      attributes.merge!(abilities).merge!('is_active' => not_using_system.include?(ea.id) ? 0 : 1)
      attributes.merge!('biz_uid' => "biz_#{ea.attributes['business_id']}")
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

  def is_tdm?
    (self.supervisor? || self.teamlead?) && self.organization.is_tdm_org?
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
           ON      t.supervisor_id = supervisors.id) SELECT id FROM supervisors
    )data
    INNER JOIN users u ON u.id = data.id
    WHERE
    u.role = 'supervisor' OR u.role = 'teamlead'
    SQL
    [self.id] + ActiveRecord::Base.connection_pool_execute(sql).map { |el| el['id'].to_i }
  end

  # description: http://postgresql.ru.net/manual/queries-with.html
  def officer_descendants_unscoped_organization_ids
    orgs = if self.officer?
      [self.organization.try(:id)]
    elsif self.chief?
      Rails.cache.fetch("officer_descendants_unscoped_organization_ids_#{self.id}", expires_in: 12.hours) do
        sql = <<-SQL
        SELECT DISTINCT u.organization_id org_id FROM
        (
        WITH RECURSIVE supervisors(id, supervisor_id) AS
              (SELECT id, supervisor_id FROM users WHERE supervisor_id = #{self.id}
               UNION
               SELECT  t.id, t.supervisor_id
               FROM    supervisors
               INNER JOIN users t
               ON      t.supervisor_id = supervisors.id) SELECT id FROM supervisors
        )data
        INNER JOIN users u ON u.id = data.id
        WHERE
        u.role = 'teamlead'
        SQL
        ActiveRecord::Base.connection_pool_execute(sql).map { |el| el['org_id'].to_i }
      end
    end
    orgs = orgs + Organization.where(group_id: organization.group_id, is_tdm_org: false).pluck(:id) if is_tdm?
    orgs
  end

  def can_export_scorecard?
    self.business&.generate_scorecard
  end

  def subscribed_org_ids
    @subscribed_org_ids ||=
        self.self_and_descendants.includes(:organization).teamleads.
        select('DISTINCT organization_id').
        pluck(:organization_id) ||
        self.try(:organization_id) ||
        []
  end

  def api_nearby_radius
    role == 'trade_person' ? nil : actual_nearby_radius.to_f * 0.001 # client expect radius as float in km
  end

  def pin_required
    return true if Role.has_managed_business.include?(role)
    self&.business&.pin_required.presence || Business::DEFAULT_OPTIONS[:pin_required]
  end

  private

  def supervisor_is_supervisor
    unless self.supervisor.supervisor?
      errors.add :supervisor_id, 'only supervisor role is available for supervisor'
    end
  end

  def route_id_uniqueness
    user = User.includes(:business).where(route_id: route_id, business_id: business_id).where.not(id: id).first

    if user
      errors.add(:route_id, :taken, business_name: user.business&.name)
    end
  end

  def actual_nearby_radius
    if Role.chiefs_with_teamlead.include? self.role
      self.business&.chief_nearby_radius || Location::NEARBY_DEFAULT[:chief_nearby_radius]
    else
      self.business&.nearby_radius || Location::NEARBY_DEFAULT[:nearby_radius]
    end
  end
end
