# This disables geocoder's web address lookup and falls to
# local json response files parsing. Comment if you need to query
# cloud services again
require Rails.root.join('features', 'support', 'geocoder.rb').to_s

Rails.application.configure do
  Paperclip::Attachment.default_options.merge!({path: ':rails_root/public/system/:rails_env/:class/:attachment/:id_partition/:style/:filename',
                                                url: '/system/:rails_env/:class/:attachment/:id_partition/:style/:filename'})
  # Settings specified here will take precedence over those in config/application.rb

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Log error messages when you accidentally call methods on nil
  config.eager_load = false

  # Configure static asset server for tests with Cache-Control for performance
  config.serve_static_files = true
  config.static_cache_control = "public, max-age=3600"
  config.assets.debug = true
  config.assets.compress = false

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection    = false

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr

  # ActionMailer Config
  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  hostname = '127.0.0.1:8888'
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = true
  config.action_mailer.default_url_options = { :host => hostname }
  
  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
  
  config.gcm_notifier = GcmNotifierDevelopment

  config.aws_uploader = AwsUploader
  config.aws_options = {}
  config.aws_export_options = {}

  config.cache_store = :memory_store
  ActiveSupport::Cache::Store.logger = Rails.logger

  #config.aws_uploader = AwsPhotoUploadJob
  #config.aws_options = {:storage => :s3, :s3_credentials => {:bucket => 'sfa-development', :s3_host_name => 's3-eu-central-1.amazonaws.com', :url => ':s3_domain_url'}}

  Faker::Config.locale = ENV['CIRCLECI'] ? :ru : :en
  config.active_job.queue_adapter = :test
  config.my_order_server = 'http://myorder_test.example.com'
  ENV['RAILS_TEMP'] = "#{Rails.root}/spec/fixtures/tmp"
  config.history_period_in_days_for_lenta_items = 99999

  config.web_api_url = "http://#{hostname}/web_api"
end
