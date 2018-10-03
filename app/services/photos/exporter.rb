require 'fileutils'

module Photos
  class Exporter
    include ThreadVars
    include Helpers

    attr_accessor :photos_processor, :zip_full_path, :photo_export

    def initialize(photo_export)
      @photo_export = photo_export
      initialize_global_vars!
      opts = prepare
      photo_export.update! opts
      @photos_processor = Photos::Processor.new photo_export, 256, 64 # max_concurretncy <= 128
    end

    def process
      PhotoExport::PROCESSING_STAGES.each do |stage|
        begin
          puts "#{Time.now}: ###### BEGIN #{stage}"
          send(stage)
          puts "#{Time.now}: ###### END #{stage}"
        rescue => e
          puts "***** ERROR"
          handle_error(stage, e)
          return false
        end
      end
      puts "***** DONE"
      true
    ensure
      puts "***** ENSURE"
      photo_export.update! ended_at: Time.now
      clean_up! if photo_export.status == 'finished'
    end

    private

    def initialize_global_vars!
      super
      global_vars[:logger] = Sidekiq.logger
    end

    def download_photos
      return false if photos_processor.photos.size.zero?
      puts "#{Time.now}: ###### BEGIN #{__method__}"
      puts "Should process #{photos_processor.photos.size} photos"
      begin
        photos_processor.download_typhoeus
      rescue => error
        puts "#{Time.now}: -+-+-+-+-+-+-+--+-+-+-+-+-+-+- ERROR #{__method__}"
        puts error
        puts :error
        handle_error(:download_photos, error)
      end
      puts "#{Time.now}: ###### END #{__method__}"
    end

    def create_local_folder
      FileUtils.mkpath(photo_export.local_temp_folder)
    end

    def make_archive
      puts "#{Time.now}: ###### BEGIN #{__method__}"
      self.zip_full_path = File.join(photo_export.local_temp_folder, file_name)

      FileUtils.rm_f zip_full_path

      images = collect_files_except_filter(photo_export.local_temp_folder, photo_export.file_include_filter, file_name)
      total = images.size

      entry_weight = 28.0/total.to_f
      logger.info "Total files=#{total}"

      Zip::File.open(zip_full_path, true) do |zip_file|
        images.each_with_index do |img, i|
          zip_file.add(img.sub("#{photo_export.local_temp_folder}/",''), img)
          logger.info "Add to Zip at #{(i*100.0/total).to_i}%" if i % 100 == 0
          update_percentage(entry_weight*10) if i%10 == 0
        end
      end
      puts "#{Time.now}: ###### END #{__method__}"
    end

    def clean_up!
      @photo_export.reload
      FileUtils.rm_rf(photo_export.local_temp_folder)
      super
    end

    def upload_archive
      photo_export.update!(aws_file: File.open(zip_full_path))
      puts photo_export.aws_file.url.gsub(/(http(s)?:\/\/)?(.*.com)\//, 'http://eu.mstdev.ru/')
    end

  end
end
