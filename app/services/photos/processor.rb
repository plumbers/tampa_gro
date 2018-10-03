require 'aws-sdk'

module Photos
  class Processor
    include ThreadVars
    include Helpers
    include ActionView::Helpers::DateHelper

    delegate :source_bucket_name, :local_temp_folder, :filters, to: :object

    attr_reader :filtered_folders
    
    def download(photo)
      source_file_name = photo.aws_image.path[1..-1] || photo.image.path
      raise 'Source file not found' if source_file_name.nil?
      date             = photo.started_date.in_time_zone(photo.timezone)
      target_file_name = target_file_name(date, photo)
      target_path      = "#{local_temp_folder}/#{date_string(date)}"
      file_path        = File.join(File.expand_path(target_path), target_file_name)

      FileUtils.mkpath target_path

      if File.exists?(file_path)
        logger.info "Using existing photo #{file_path}"
      else
        logger.info "Downloading photo #{source_bucket_name}#{source_file_name} to #{target_path}/#{target_file_name}"
        s3client.get_object({ bucket: source_bucket_name, key: source_file_name }, target: file_path)
      end

    rescue Exception => e
      ap "source_bucket_name: #{source_bucket_name}"
      ap "src: '#{source_file_name}'"
      ap "dst: '#{target_path}/#{target_file_name}'"
      handle_error "photo#{photo.id}", e
    end

    def photos
      return @photos if @photos
      @photos = Photo.filtered(filters.to_h.compact)
      object.update_attributes(photos_count: @photos.size)

      logger.debug "Should download #{photos.to_sql}"
      logger.info "Should download #{photos.size} files"
      @photos
    end

    private

    def target_file_name(date, photo)
      extname          = File.extname(photo.aws_image.path)
      date_string      = date_string(date)
      without_question = "#{photo.external_id}_#{date_string}_#{photo.id}#{extname}"
      question_name    = photo.question&.title&.gsub(/[\x00\/\\:\*\?\"<>\|]/, '')

      target_file_name = if question_name.present?
                           available     = 100 - without_question.length
                           question_name = question_name[0..available-2] if available < question_name.length
                           "#{photo.external_id}_#{question_name}_#{date_string}_#{photo.id}#{extname}"
                         else
                           without_question
                         end
      NameCleaner.clean(target_file_name)
    end

    def date_string(date)
      date.to_date.strftime('%d%m%Y')
    end

  end
end
