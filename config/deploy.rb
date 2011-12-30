require "bundler/capistrano"
#load 'deploy/assets'
default_run_options[:pty] = false
set :application, 'www.4star.cn'
set :scm, "git"
set :repository, "git@github.com:wxmcan/mystore.git"
set :branch, "master"

set :deploy_to, "/var/www/apps/#{application}"
role :app, application, :primary => true
role :web, application, :primary => true

set :user, "bob" #proc { Capistrano::CLI.password_prompt("Server User: ") }
set :password, "fishmango" #proc { Capistrano::CLI.password_prompt("Server Password : ") }
set :use_sudo, false

set :rvm_ruby_string, "ree-1.8.7-2011.03"
set :rvm_type, :user

namespace :deploy do
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_release} && touch tmp/restart.txt"
  end

  task :symlink_shared do
    run "cd #{shared_path}/config/ && cp database.example.yml database.yml"
    run "ln -nfs #{shared_path}/bundle #{release_path}/vendor/bundle"
    run "ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
    run "ln -nfs #{shared_path}/assets #{release_path}/public/assets"
    run "ln -nfs #{shared_path}/db/sphinx #{release_path}/db/sphinx"
    run "ln -nfs #{shared_path}/cache/products #{release_path}/public/products"
    run "ln -nfs #{shared_path}/sitemaps #{release_path}/public/sitemaps"
  end

  desc "Update the crontab file"
  task :update_crontab, :roles => :db do
    run "cd #{current_release} && whenever --update-crontab #{application}"
  end

  desc "Sync the shared directory."
  task :shared do
    system "rsync -vr --exclude='.svn' config #{user}@#{application}:#{shared_path}/"
    #    system "rsync -vr --exclude='.svn' public/asset #{user}@#{application}:#{shared_path}/"
    #    system "rsync -vr --exclude='.svn' db/sphinx #{user}@#{application}:#{shared_path}/db"
  end

  task :jammit do
    run "cd #{current_path} && jammit"
  end
end

namespace :delayed_job do
  def rails_env
    #    fetch(:rails_env, false) ? "RAILS_ENV=#{fetch(:rails_env)}" : ''
    "RAILS_ENV=production"
  end

  desc "Stop the delayed_job process"
  task :stop, :roles => :app do
    run "cd #{current_release}; #{rails_env} script/delayed_job stop"
  end

  desc "Start the delayed_job process"
  task :start, :roles => :app do
    run "cd #{current_release}; #{rails_env} script/delayed_job -n 6 start"
  end

  desc "Restart the delayed_job process"
  task :restart, :roles => :app do
    stop
    wait_for_process_to_end('delayed_job')
    start
  end

  def wait_for_process_to_end(process_name)
    run "COUNT=1; until [ $COUNT -eq 0 ]; do COUNT=`ps -ef | grep -v 'ps -ef' | grep -v 'grep' | grep -i '#{process_name}'|wc -l` ; echo 'waiting for #{process_name} to end' ; sleep 2 ; done"
  end

end

namespace :ts do
  task :rebuild do
    run "cd #{current_release}; rake ts:rebuild RAILS_ENV=production"
  end

  desc "Delta index"
  task :delta, :roles => :app do
    run "cd #{current_path} && rake thinking_sphinx:index:delta RAILS_ENV=production"
  end

  desc "Index only"
  task :io, :roles => :app do
    run "cd #{current_path} && rake thinking_sphinx:index INDEX_ONLY=true RAILS_ENV=production"
  end

  desc "Stop the sphinx server"
  task :stop, :roles => :app do
    run "cd #{current_path} && rake thinking_sphinx:configure RAILS_ENV=production && rake thinking_sphinx:stop RAILS_ENV=production"
  end


  desc "Start the sphinx server"
  task :start, :roles => :app do
    run "cd #{current_path} && rake thinking_sphinx:configure RAILS_ENV=production && rake thinking_sphinx:start RAILS_ENV=production"
  end

  desc "Restart the sphinx server"
  task :restart, :roles => :app do
    stop
    start
  end
end

namespace :sitemap do
  task :refresh, :roles => :app do
    run "cd #{current_release} && rake sitemap:refresh RAILS_ENV=production"
  end

  task :refresh_no_ping, :roles => :app do
    run "cd #{current_release} && rake sitemap:create RAILS_ENV=production"
  end
end

before "deploy:symlink", "deploy:symlink_shared"
#before "deploy:restart", "deploy:migrate"
#before "deploy:restart", "deploy:update_crontab"
#before "deploy:restart", "ts:restart"
#before "deploy:restart", "delayed_job:restart"
