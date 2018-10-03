module Photos
  class Processor
    include ThreadVars
    include Helpers
    include ActionView::Helpers::DateHelper

    delegate :local_temp_folder, :filters, to: :photo_export

    attr_reader   :filtered_folders
    attr_accessor :photo_export, :photos, :filtered_folders, :toss_folders, :hydra, :batch_size, :max_concurrency

    def initialize(photo_export, batch_size, max_concurrency)
      @batch_size = batch_size
      @max_concurrency = max_concurrency
      @toss_folders = photo_export.toss_folders
      @photo_export = photo_export

      Typhoeus::Config.verbose = false
      @hydra = Typhoeus::Hydra.new(max_concurrency: max_concurrency)
    end

    def download_typhoeus(rel_photos = aws_photos())
      puts "#{Time.now}: ###### BEGIN #{__method__}"
      rel_photos_count = rel_photos.size
      i, bsize = 0, batch_size
      start_time = Time.now
      entry_weight = 60.0/rel_photos_count
      rel_photos.find_in_batches(batch_size: bsize) do |_photos|
        puts "batch #{bsize*i} in #{_photos.size}-*-#{rel_photos_count}" if i<2
        percent = (bsize*i*100.0/rel_photos_count).to_i
        time_past = ((Time.now-start_time)/60).round(1)
        time_eta = (time_past*(100.0-percent)/[percent, 0.000001].max).round(1)
        puts "#{Time.now}: spent #{time_past} min - processed (#{percent}%) = #{bsize*i}/#{rel_photos_count} ETA #{time_eta} min" if i>1
        i+=1
        _photos.each_with_index do |photo, i|
          begin
            photo_uri="s3-eu-central-1.amazonaws.com/vk-customers/#{photo.aws_path}"
            # puts photo_uri
            request = Typhoeus::Request.new(photo_uri)
            # request = Typhoeus::Request.new("http://eu.mstdev.ru/vk-customers/#{photo.aws_path}")
            request.on_complete do |response|
              # write_file url, response.body
              if response.success?
                # puts :try_process
                process(photo, response.body)
              elsif response.timed_out?
                puts "got a time out"
              elsif response.code == 0
                # Could not get an http response, something's wrong.
                puts response.return_message
              else
                # Received a non-successful http response.
                puts "HTTP request failed: " + response.code.to_s
              end
            end
            hydra.queue request
          rescue => error
            puts error
            process_error(error)
          ensure
            next
          end
        end
        hydra.run
        update_percentage(entry_weight*10) if i%10 == 0
      end
      puts "#{Time.now}: ###### END #{__method__}"
    end

    def save_to_tempfile(filename, resp_body)
      dirname = File.dirname(filename)
      FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
      file = File.new(filename, 'wb+')
      file.binmode
      file.write(resp_body)
      file.flush
      file
    end

    def process(photo, resp_body)
      tries = 3
      begin
        source_file_name = photo.aws_path
        return if source_file_name.blank?
        date = photo.started_date.in_time_zone(photo.timezone)
        nested_path = toss_folders.blank? ? '' : toss_folders.split(',').map{ |part| photo.send(part) }.join('/')
        target_path = File.join local_temp_folder, nested_path, date_string(date)
        target_file_name = File.join target_path, target_file_name(date, photo)
        save_to_tempfile(target_file_name, resp_body)
      rescue Exception=>e
        puts e
        Rails.logger.info e
        tries -= 1
        if tries > 0
          retry
        else
          puts "SKIP target_file_name=#{target_file_name}, dst='#{target_file_name}' src = '#{source_file_name}'"
        end
      end
    end



    def aws_photos
      return @aws_photos if @aws_photos

      filters = photo_export.filters.to_h.compact
      @aws_photos = Photo.filtered(filters)
      photo_export.update_attributes photo_export.options.merge(photos_count: @aws_photos.size)
      Rails.logger.info "Should sync #{@aws_photos.to_sql}"
      Rails.logger.info "Should sync #{@aws_photos.size} files"
      puts "Should sync #{@aws_photos.to_sql}" if @aws_photos.size < 100
      puts "Should sync #{@aws_photos.size} files"
      @aws_photos
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

    def clean_path(path)
      path&.gsub(/[\(\)\x00\/\\:\*\?\"<>\|]/, '')
    end
  end
end

