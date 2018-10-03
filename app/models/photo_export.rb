class PhotoExport < Export
  CONTENT_VALIDATOR =
    {
      content_type: /\Azip\Z/,
      message: I18n.t('models.photo_export.unsupported_type_file')
    }

  PROCESSING_STAGES = %w(download_photos make_archive upload_archive)
  # PROCESSING_STAGES = %w(download_photos)

  FILTERS = { limit: :integer ,
              date_from: :date_time,
              date_till: :date_time,
              date_exclude: :date_array,

              business_id: :integer,
              chief_id: :integer,

              location_ids: :integer_array,
              location_external_ids: :string_array,
              company_ids: :integer_array,
              location_type_ids: :integer_array,
              signboard_ids: :integer_array,
              question_ids: :integer_array,
              checkin_type_ids: :integer_array,
              exclude_photo_ids: :integer_array,
              organization_ids: :integer_array,
              checkin_ids: :integer_array,
              location_field_ids: :integer_array
            }

  jsonb_accessor :options,
                 jid: :string,
                 started_at: :date_time,
                 ended_at: :date_time,
                 photos_count: :integer,
                 source_bucket_name: :string,
                 local_temp_folder: :string,
                 chief_mobile: :string,
                 toss_folders: :string_array,
                 file_name: :string,
                 file_include_filter: :string,
                 file_exclude_filter: :string,
                 filters: FILTERS

  # before_save :set_defaults, :set_photos_count

  FILTERS.keys.each do |filter|
    define_method filter do
      self.filters.send(filter)
    end
  end

  def reset!
    self.update! percent: 0, status: :not_started
  end

  def restart!
    self.update! status: :in_progress
  end

  private

  def set_defaults
    self.filters.business_id ||= UserUnscoped.find(chief_id)&.business_id
  end

  def set_photos_count
    self.photos_count ||= ::Photo.filtered(self.filters.to_h).size
  end

end
