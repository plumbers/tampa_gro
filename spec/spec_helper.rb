ENV["RAILS_ENV"] ||= 'test'
require 'factory_girl_rails'
require 'simplecov'
require File.expand_path("../../config/environment", __FILE__)
require Rails.root.join('spec/support/shoulda_matchers_helper')
require 'rspec/rails'
require 'rubygems'
require 'email_spec'
require 'factory_girl'
require 'database_cleaner'
require 'sidekiq/testing'
require 'paper_trail/frameworks/rspec'
require Rails.root.join('features/support/geocoder.rb')
require Rails.root.join('features/support/timezone_getter.rb')
require Rails.root.join('features/support/assistance.rb')
# require 'rspec/active_job'
require 'rspec-sidekiq'
require 'webmock/rspec'
require 'whenever'
require 'shoulda/whenever/schedule_matcher'
require 'rspec/matchers/fail_matchers'

require 'test_prof/recipes/rspec/let_it_be'

ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

if ENV['CIRCLE_ENV'] || !ENV['DEBUG']
  def ap(object, options={})
  end
end

# Loading more in this block will cause your tests to run faster. However,
# if you change any configuration or code from libraries loaded here, you'll
# need to restart spork for it take effect.

# This file is copied to spec/ when you run 'rails generate rspec:install'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

Rails.logger.level = 0

# ActiveJob::Base.queue_adapter = :test
# unload publisher, but allow net connection
Rspec::Assistance.scorecard_event_bus_switch :off
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.color = true
  config.infer_spec_type_from_file_location!
  config.tty = true
  config.formatter = :documentation

  config.include(EmailSpec::Helpers)
  config.include(EmailSpec::Matchers)

  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  config.before(:context, :rabbit) do
     Rspec::Assistance.scorecard_event_bus_switch :on
   end

  config.after(:context, :rabbit) do
    Rspec::Assistance.scorecard_event_bus_switch :off
  end

  # suppress stdout/puts trace when expected error raised
  config.around(:each, :expect_failure) do |example|
    original_stderr = $stderr
    original_stdout = $stdout
    config.before { allow($stderr).to receive(:puts) }
    config.before { allow($stdout).to receive(:puts) }
    example.run
    $stderr = original_stderr
    $stdout = original_stdout
  end

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  config.include FactoryGirl::Syntax::Methods
  config.include Devise::Test::ControllerHelpers, type: :controller

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false 

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  config.before(:suite) do
    puts "Started at: #{Time.now}"
    DatabaseCleaner.clean_with(:truncation, { except: %w[spatial_ref_sys]})
    if SupportDatabase.has_config?
      DatabaseCleaner[:active_record, { model: SupportDatabase }].clean_with(:truncation, { except: %w[spatial_ref_sys]})
    end
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each) do
    DatabaseCleaner.start
    DatabaseCleaner[:active_record, { model: SupportDatabase }].start if SupportDatabase.has_config?
  end

  config.after(:each) do
    Timecop.return
    DatabaseCleaner.clean
    DatabaseCleaner[:active_record, { model: SupportDatabase }].clean if SupportDatabase.has_config?
  end

  config.before(:context) do
    DatabaseCleaner.start
    DatabaseCleaner[:active_record, { model: SupportDatabase }].start if SupportDatabase.has_config?
  end

  config.after(:context) do
    Timecop.return
    DatabaseCleaner.clean
    DatabaseCleaner[:active_record, { model: SupportDatabase }].clean if SupportDatabase.has_config?
  end

  config.before(:each) do |example|
    Sidekiq::Worker.clear_all

    if example.metadata[:sidekiq] == :fake
      Sidekiq::Testing.fake!
    elsif example.metadata[:sidekiq] == :inline
      Sidekiq::Testing.inline!
    elsif example.metadata[:type] == :acceptance
      Sidekiq::Testing.inline!
    else
      Sidekiq::Testing.fake!
    end
  end

  # config.include RSpec::ActiveJob
  # config.include ActiveJob::TestHelper#, type: :job
  # # clean out the queue after each spec
  # config.after(:each) do
  #   ActiveJob::Base.queue_adapter.enqueued_jobs = []
  #   ActiveJob::Base.queue_adapter.performed_jobs = []
  # end
  #
  # config.around(:each, perform_enqueued: true) do |example|
  #   @old_perform_enqueued_jobs = ActiveJob::Base.queue_adapter.perform_enqueued_jobs
  #   @old_perform_enqueued_at_jobs = ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs
  #   ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
  #   ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = true
  #   ActiveJob::TestAdapter.perform_enqueued_jobs = true
  #   example.run
  #   ActiveJob::Base.queue_adapter.perform_enqueued_jobs = @old_perform_enqueued_jobs
  #   ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = @old_perform_enqueued_at_jobs
  #   ActiveJob::TestAdapter.perform_enqueued_jobs = false
  # end

  SimpleCov.command_name ENV['CIRCLECI'] ? "spec_#{ENV['CIRCLE_NODE_INDEX']}" : 'spec'
  SimpleCov.start do
    add_filter ['/spec/', '/features/', '/config/']
  end

  config.around(:each, :caching) do |example|
    caching = Rails.configuration.cache_store
    Rails.configuration.cache_store = example.metadata[:caching] ? :memory_store : :null_store
    example.run
    Rails.configuration.cache_store = caching
  end

  # config.around(:each, :profile) do |example|
  #   example_name = example.full_description.parameterize[0..180]
  #   path = Rails.root.join("tmp/stackprof-cpu-test-#{example_name}.dump")
  #   StackProf.run(mode: :cpu, out: path.to_s) do
  #     example.run
  #   end
  # end unless ENV['CIRCLECI']

end

RSpec::Sidekiq.configure do |config|
  # Clears all job queues before each example
  config.clear_all_enqueued_jobs = true # default => true

  # Whether to use terminal colours when outputting messages
  config.enable_terminal_colours = true # default => true

  # Warn when jobs are not enqueued to Redis but to a job array
  config.warn_when_jobs_not_processed_by_sidekiq = true # default => true
end

#uncomment the following line to use spork with the debugger
#require 'spork/ext/ruby-debug'

# --- Instructions ---
# Sort the contents of this file into a Spork.prefork and a Spork.each_run
# block.
#
# The Spork.prefork block is run only once when the spork server is started.
# You typically want to place most of your (slow) initializer code in here, in
# particular, require'ing any 3rd-party gems that you don't normally modify
# during development.
#
# The Spork.each_run block is run each time you run your specs.  In case you
# need to load files that tend to change during development, require them here.
# With Rails, your application modules are loaded automatically, so sometimes
# this block can remain empty.
#
# Note: You can modify files loaded *from* the Spork.each_run block without
# restarting the spork server.  However, this file itself will not be reloaded,
# so if you change any of the code inside the each_run block, you still need to
# restart the server.  In general, if you have non-trivial code in this file,
# it's advisable to move it into a separate file so you can easily edit it
# without restarting spork.  (For example, with RSpec, you could move
# non-trivial code into a file spec/support/my_helper.rb, making sure that the
# spec/support/* files are require'd from inside the each_run block.)
#
# Any code that is left outside the two blocks will be run during preforking
# *and* during each_run -- that's probably not what you want.
#
# These instructions should self-destruct in 10 seconds.  If they don't, feel
# free to delete them.
