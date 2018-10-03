# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

job_type :command_with_system_path, 'cd :path/public/system && :task :output'

def every_if_enabled(name, period, options = {})
  unless ENV["skip_#{name}"]
    every period, options do
      class_name = name.split('_').map{ |word| word[0] = word[0].upcase; word }.join
      runner "#{class_name}.run"
    end
  end
end

every_if_enabled 'users_encryption_key_regeneration',       '30 0 1 */3 *',     roles: :db

every '0 4 * * *' do
  command_with_system_path 'find . -type d -empty -delete'
end
