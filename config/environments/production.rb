Rails.application.configure do
  # Verifies that versions and hashed value of the package contents in the project's package.json
  config.webpacker.check_yarn_integrity = false

  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true
  config.action_view.cache_template_loading = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both thread web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like nginx, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_files = false

  # Compress JavaScripts and CSS
  config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Generate digests for assets URLs
  config.assets.digest = true

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # See everything in the log (default is :info)
  # config.log_level = :info

  # Prepend all log lines with the following tags
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile += %w( search.js )

  # Disable delivery errors, bad email addresses will be ignored
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # ActionMailer Config
  # Setup for production - deliveries, no errors raised
  hostname = 'mstlab24.ru'
  config.action_mailer.default_url_options = { :host => hostname }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.default charset: "utf-8", from: "invitation@#{hostname}"

  config.action_mailer.smtp_settings = YAML.load_file("#{Rails.root.to_s}/config/email_accounts.yml")['sendgrid'].merge({domain: hostname}).symbolize_keys

  # Disable automatic flushing of the log to improve performance.
  # config.autoflush_log = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  config.gcm_notifier = GcmNotifierDevelopment
  config.is_customers_host = true
  config.should_update_scorecard_data_marts = false
  config.scorecard_autogenerate = true
  config.should_orders_exchange_data = true

  config.aws_uploader = AwsPhotoUploadWorker
  config.aws_options = { storage: :s3,
                         s3_region: ENV['AWS_REGION'],
                         s3_protocol: 'http',
                         s3_options: { http_open_timeout: 3, http_read_timeout: 3 },
                         s3_credentials: { bucket: 'vk-customers',
                                           s3_host_name: 's3-eu-central-1.amazonaws.com',
                                           url: ':s3_domain_url' } }
  config.send_sms = true

  config.aws_export_options = {
    storage: :s3,
    s3_protocol: 'http',
    s3_region: ENV['AWS_REGION'],
    s3_credentials: { bucket: 'vk-exports',
                      s3_host_name: 's3-eu-central-1.amazonaws.com',
                      url: ':s3_domain_url'
    }
  }
  config.my_order_server = 'https://order.mstlab24.ru'
end
