require 'capistrano/ext/multistage'
require "bundler/capistrano"
require "rvm/capistrano"
require "whenever/capistrano"
require "delayed/recipes"
# load 'lib/tasks/upload_files'

set :rvm_ruby_string, '1.9.3@blog_knowmaths'

set :stages, %w(staging production)
set :default_stage, 'staging'

server "46.51.129.204", :web, :app, :db, primary: true

set :application, "knowmaths.com"
set :user, "knowmaths"
set :deploy_via, :remote_cache
set :use_sudo, false

set :scm, "git"
set :repository, "git@github.com:damianM/typo.git"
set :branch, "master"

set :whenever_command, "bundle exec whenever"
set :whenever_environment, defer { stage }
set :whenever_identifier, defer { "#{application}_#{stage}" }

default_run_options[:pty] = true
ssh_options[:forward_agent] = true

set :deploy_to, Proc.new { "/var/www/sites/#{subdomain}knowmaths.com/" }

after "deploy", "deploy:cleanup" # keep only the last 5 releases
after "deploy:update_code",  "deploy:migrate"

namespace :deploy do
  %w[start stop restart].each do |command|
    desc "#{command} unicorn server"
    task command, roles: :app, except: {no_release: true} do
      run "/etc/init.d/unicorn_#{subdomain}#{application} #{command}"
    end
  end

  task :setup_config, roles: :app do
    sudo "ln -nfs #{current_path}/config/#{subdomain}nginx.conf /etc/nginx/sites-enabled/#{subdomain}#{application}"
    sudo "ln -nfs #{current_path}/config/#{subdomain}unicorn_init.sh /etc/init.d/unicorn_#{subdomain}#{application}"
    run "mkdir -p #{shared_path}/config"
    put File.read("config/database.example.yml"), "#{shared_path}/config/database.yml"
    puts "Now edit the config files in #{shared_path}."
  end
  after "deploy:setup", "deploy:setup_config"

  task :symlink_config, roles: :app do
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
  end
  after "deploy:finalize_update", "deploy:symlink_config"

  desc "Make sure local git is in sync with remote."
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/master`
      puts "WARNING: HEAD is not the same as origin/master"
      puts "Run `git push` to sync changes."
      exit
    end
  end
  before "deploy", "deploy:check_revision"
end

