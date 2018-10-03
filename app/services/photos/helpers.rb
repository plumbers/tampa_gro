require 'zip/zip'
require 'zip/zipfilesystem'
require 'errors'

module Photos
  module Helpers

    def file_name
      return @file_name if defined?(@file_name)
      user = User.find(photo_export.filters.chief_id)
      @file_name = [ 'photo',
        Business.find(photo_export.filters.business_id).name.parameterize,
        user.name.parameterize,
        user.mobile_phone,
        photo_export.filters.date_from.strftime('%d%m%Y'),
        photo_export.filters.date_till.strftime('%d%m%Y'),
        photo_export.id ].join('-') + '.zip'

      @file_name = NameCleaner.clean(@file_name, exclude_regex: /[\\:\/\*|"<>]/)
    end

    def listen_synced_local_folder(local_folder, max_count)
      counters = { added: 0, modified: 0, removed: 0 }
      total_opts = 0

      listener = Listen.to(local_folder, latency: 10, wait_for_delay: 10 ) do
        total_opts += 1
        counters[:added]    += 1 if added.present?
        counters[:modified] += 1 if modified.present?
        counters[:removed]  += 1 if removed.present?
        (total_opts * 100.0/max_count).to_i
      end

      listener.start
    end

    def update_percentage(diff_secs)
      photo_export = global_vars[:photo_export]
      return if photo_export.nil?
      photo_export.reload
      photo_export.update_column :percent, photo_export.percent.to_f + diff_secs
    end

    def handle_error(key, e)
      ap e.message
      ap e.backtrace
      errors.add key, e, e.backtrace.first(15)
    end

    def logger(obj = nil)
      global_vars[:logger] ||= obj || Sidekiq.logger
    end

    private

    def collect_files_except_filter(local_folder, file_filters, file_name)
      files = Dir["#{local_folder}/**/**"].reject { |f| f == file_name }
      file_filters ? files.select { |f| f=~ /#{file_filters.join '|'}/ } : files
    end

  end
end
