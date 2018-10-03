set :user, 'pofik'
set :default_env, fetch(:default_env).merge({ 'name' => "#{fetch(:user)}"})
server "zippy.mstdev.ru", user: fetch(:user), roles: %w{app web db support_db}, primary: true, port: 744
set :sidekiq_user, fetch(:user)
set :sidekiq_processes, -> { 6 }
set :deploy_to, "/home/#{fetch(:user)}/#{fetch(:application)}"
set :tmp_dir, "#{fetch(:deploy_to)}/tmp"
set :rails_env, "#{fetch(:user)}_staging"
