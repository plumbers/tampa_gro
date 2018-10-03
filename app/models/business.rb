# == Schema Information
#
# Table name: businesses
#
#  id                      :integer          not null, primary key
#  name                    :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  options                 :jsonb
#  canonical_name          :string
#  generate_scorecard      :boolean
#  features                :string
#  questionary_constructor :
#  nearby_map              :
#  canonical_name :string
#

class Business < ApplicationRecord
  FEATURES = %i(orders questionaries)

  has_many :users
  has_many :kpi_templates

  DEFAULT_OPTIONS = { questionary_constructor: { hidden_answer_types: [] },
                      nearby_map: Location::NEARBY_DEFAULT,
                      generate_scorecard: false, complex_passwords: false,
                      features: [],
                      encryption: EncryptionKey::DEFAULT_OPTS
  }

  jsonb_accessor :options,
                 questionary_constructor: { hidden_answer_types: :string_array },
                 nearby_map: { nearby_radius: :integer, chief_nearby_radius: :integer },
                 generate_scorecard: :boolean, complex_passwords: :boolean,
                 features: :string_array,
                 encryption: { key: { length: :integer, type: :string }, expiration_period: :integer }

  after_initialize :set_default_options

  with_options presence: true, uniqueness: true, length: { maximum: 40 } do
    validates :name
    validates :canonical_name
  end

  validates :canonical_name, format: { with: /\A[0-9a-zA-Z\-]{1,}\z/i }

  validate :nearby_radius_within_limits

  scope :with_file_kpi_templates, -> do
    joins(:kpi_templates).where(kpi_templates: { source_type: KpiTemplate.source_types[:file] }).
      distinct
  end

  def top
    @top ||= User.where(business_id: id).
      where.not(role: Role.has_managed_business).
      where("role = 'executive' OR supervisor_id is null").
      first
  end

  # NOTE: This method is so awesome, i'll kill you if you remove it! (jk))
  def tops
    users.joins('LEFT JOIN users sv on users.supervisor_id = sv.id')
    .joins(
      <<~SQL
        INNER JOIN LATERAL
          (SELECT
          ancestor_id
          FROM user_hierarchies
          WHERE descendant_id != users.id
          AND ancestor_id = users.id
          ORDER BY generations limit 1) uh ON true
      SQL
    )
    .where('users.supervisor_id IS NULL OR sv.business_id IS NULL')
  end

  def organization_ids
    self.top&.officer_descendants_unscoped_organization_ids
  end


  def set_options(options = {})
    return if options.blank?

    options.each do |k, v|
      condition_method = :"#{k}_is_set?"
      if respond_to?(condition_method)
        self.send(k, v) unless send(condition_method)
      else
        self.send("#{k}=", v) unless changes.has_key?(k)
      end
    end
  end

  %w(nearby_radius chief_nearby_radius).each do |method|
    define_method(method) do
      self.nearby_map.send method
    end
  end

  FEATURES.each do |feature|
    define_method "#{feature}_feature?" do
      features.include?(feature.to_s)
    end
  end

  private

  def nearby_radius_within_limits
    valid_radius = true
    limits = Location::NEARBY_LIMITS
    unless nearby_map.nearby_radius.to_i.between? limits[:min_nearby_radius], limits[:max_nearby_radius]
      errors.add(:nearby_radius, I18n.t('models.businesses.settings.radius_should_fit', min: limits[:min_nearby_radius], max: limits[:max_nearby_radius]))
      valid_radius &= false
    end
    unless nearby_map.chief_nearby_radius.to_i.between? limits[:min_nearby_radius], limits[:max_chief_nearby_radius]
      errors.add(:chief_nearby_radius, I18n.t('models.businesses.settings.radius_should_fit', min: limits[:min_nearby_radius], max: limits[:max_chief_nearby_radius]))
      valid_radius &= false
    end
    valid_radius
  end

  def set_default_options
    return if persisted?
    set_options DEFAULT_OPTIONS
  end

  def nearby_map_is_set?
    nearby_map.nearby_radius.present? || nearby_map.chief_nearby_radius.present?
  end
end
