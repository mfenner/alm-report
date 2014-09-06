# config valid only for Capistrano 3.1
lock '3.2.1'

set :application, 'alm-report'
set :repo_url, 'git@github.com:articlemetrics/alm-report.git'

# Default branch is :master
set :branch, 'develop'

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/var/www/alm-report2'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
set :log_level, :info

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w{ config/database.yml config/settings.yml }

# Default value for linked_dirs is []
set :linked_dirs, %w{ bin log tmp/pids tmp/sockets vendor/bundle }

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 5

# Install gems into shared/vendor/bundle
set :bundle_path, -> { shared_path.join('vendor/bundle') }

# Use system libraries for Nokogiri
set :bundle_env_variables, 'NOKOGIRI_USE_SYSTEM_LIBRARIES' => 1

namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :publishing, :restart

  after :finishing, "deploy:cleanup"
end
