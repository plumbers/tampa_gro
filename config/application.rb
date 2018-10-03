require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

module Valkyrie
  class Application < Rails::Application

    # don't generate RSpec tests for views and helpers
    config.generators do |g|

      g.test_framework :rspec, fixture: true
      g.fixture_replacement :factory_girl, dir: 'spec/factories'


      g.view_specs false
      g.helper_specs false
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    # config.autoload_paths += %W(#{config.root}/extras)
    config.enable_dependency_loading = true
    config.autoload_paths += Dir[Rails.root.join('lib/')]
    config.autoload_paths += Dir[Rails.root.join('lib', 'additional_databases')]
    config.autoload_paths += Dir[Rails.root.join('app','models','**/')]
    config.autoload_paths += Dir[Rails.root.join('app','controllers', '**/')]
    config.autoload_paths += Dir[Rails.root.join('app','services','**/')]
    config.autoload_paths += Dir[Rails.root.join('app','jobs')]
    config.autoload_paths += Dir[Rails.root.join('app','queries','**/')]
    config.autoload_paths += Dir[Rails.root.join('app','decorators','**/')]
    config.autoload_paths += Dir[Rails.root.join('app','scheduled_tasks','**/')]
    config.autoload_paths += Dir[Rails.root.join('app','subscribers','**/')]

    config.active_job.queue_adapter = :sidekiq

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Moscow'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :ru
    config.i18n.available_locales = %i(ru en)
    config.i18n.enforce_available_locales = true



    config.filter_parameters += [:photo]

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    config.hamlcoffee.templates_path = "app/assets/templates"

    config.exceptions_app = self.routes

    # config.active_record.raise_in_transactional_callbacks = true

    ActiveSupport::JSON::Encoding.time_precision = 0
    
    config.report_rollbar = (%w{eu_staging qa_staging staging production customers cerberus dev1_staging}.include?(Rails.env) && ENV['USER'] == 'atlantic') || (Rails.env == 'egor_staging' && ENV['USER'] == 'egor') || (Rails.env == 'vadim_staging' && ENV['USER'] == 'vadim') || (Rails.env == 'maxim_staging' && ENV['USER'] == 'maxim')|| (Rails.env == 'silentshade_staging' && ENV['USER'] == 'silentshade')
    config.send_sms       = false
    
    config.api_versions = [3, 4, 5, 6, 7, 8, 9, 10]
    config.is_customers_host = false
    config.should_update_scorecard_data_marts = false
    config.sms_sender = :sms_ru
    config.ymaps = ActiveSupport::OrderedOptions.new
    config.ymaps.version = '2.1.47'
    config.ymaps.css_version = '2-1-47'

    config.feedback_emails = ['files.mst@it-atlantic.com']

    config.log_level = :error

    # AWS S3 CLI config && credentials
    ENV['AWS_REGION'] = ENV['AWS_DEFAULT_REGION']    = 'eu-central-1'
    ENV['AWS_ACCESS_KEY_ID']     = Rails.application.secrets.s3_access_key_id
    ENV['AWS_SECRET_ACCESS_KEY'] = Rails.application.secrets.s3_secret_access_key
    ENV['RAILS_TEMP'] = "#{Rails.root}/tmp"

    config.action_dispatch.perform_deep_munge = false
  end
end
