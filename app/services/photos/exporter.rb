require 'fileutils'

module Photos
  class Exporter
    include ThreadVars
    include Helpers

    attr_accessor :photos_processor, :zip_full_path

    def initialize(object)
      @object = object
      initialize_global_vars!
      @photos_processor = Photos::Processor.new
    end

    def process
      object.update! started_at: Time.now, local_temp_folder: "#{ENV['RAILS_TEMP']}/#{object.id}"

      PhotoExport::PROCESSING_STAGES.each do |stage|
        begin
          return false unless send(stage)
        rescue => e
          handle_error(stage, e)
          return false
        end
      end
      true
    ensure
      object.update! ended_at: Time.now
      clean_up!
    end

    private

    def initialize_global_vars!
      super
      global_vars[:logger] = Sidekiq.logger
      global_vars[:s3_client] ||= Aws::S3::Client.new(aws_config[:s3_options].
        merge(force_path_style: true, endpoint: "http://#{aws_config[:s3_credentials][:s3_host_name]}"))

    end

    def download_photos
      return false if photos_processor.photos.size.zero?

      entry_weight = 60.0/photos_processor.photos.size.to_f

      photos_processor.photos.each_with_index do |photo, i|
        begin
          photos_processor.download(photo)
        rescue => e
          handle_error photo, e
        end
        update_percentage(entry_weight*10) if i%10 == 0
      end
    end

    def create_local_folder
      FileUtils.mkpath(object.local_temp_folder)
    end

    def make_archive
      self.zip_full_path = File.join(object.local_temp_folder, file_name)

      FileUtils.rm_f zip_full_path

      images = collect_files_except_filter(object.local_temp_folder, object.file_include_filter, file_name)
      total = images.size

      entry_weight = 28.0/total.to_f
      logger.info "Total files=#{total}"

      Zip::File.open(zip_full_path, true) do |zip_file|
        images.each_with_index do |img, i|
          zip_file.add(img.sub("#{object.local_temp_folder}/",''), img)
          logger.info "Add to Zip at #{(i*100.0/total).to_i}%" if i % 100 == 0
          update_percentage(entry_weight*10) if i%10 == 0
        end
      end

    end

    def clean_up!
      @object.reload
      FileUtils.rm_rf(object.local_temp_folder)
      super
    end

    def save_file
      object.update!(aws_file: File.open(zip_full_path))
    end

  end
end
