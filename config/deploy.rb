# config valid only for Capistrano 3.2.1
# lock '3.2.1'

# Normal Tasks:
#     deploy:starting    - start a deployment, make sure everything is ready
#     deploy:started     - started hook (for custom tasks)
#     deploy:updating    - update server(s) with a new release
#     deploy:updated     - updated hook
#     deploy:publishing  - publish the new release
#     deploy:published   - published hook
#     deploy:finishing   - finish the deployment, clean up everything
#     deploy:finished    - finished hook
#
# hook: after 'deploy:updated', when role is :web
#     cap deploy:laravel                 # laravel
#
# hook: after 'deploy:published', when role is :web
#     cap deploy:opcache                 # opcache

set :application, 'ec-admin'
set :repo_protocol, 'git'
set :repo_url, 'git@github.com:xionglianbo/ec-admin.git'
set :remote, 'xionglianbo'
set :branch, 'master'
set :deploy_to, '/var/www/staging'
set :current_dir, 'current'
set :pty, true
set :keep_releases, 5

if ENV['repo_protocol']
    set :repo_protocol, ENV['repo_protocol']
end

if ENV['keep_releases']
    set :keep_releases, ENV['keep_releases'].to_i
end

if ENV['branch']
    # If branch include '/', we want to replace remote and current_dir
    if ENV['branch'].include? '/'
        remote, branch = ENV['branch'].split('/', 2)
        set :remote, remote
        set :branch, branch
        if remote != 'xionglianbo'
            if branch != 'master'
                set :current_dir, branch.downcase
            else
                set :current_dir, remote.downcase
            end
        end
    else
        set :branch, ENV['branch']
    end
end

# Set Value for project
if ENV['project']
    if "#{fetch(:repo_protocol)}" == 'git'
        set :repo_url, "git@github.com:#{fetch(:remote)}/#{ENV['project']}.git"
    else
        set :repo_url, "https://github.com/#{fetch(:remote)}/#{ENV['project']}.git"
    end
    set :deploy_to, "/var/www/#{ENV['server']}/#{ENV['project']}"
    set :application, "xiong_project_#{ENV['server']}_#{ENV['project']}_#{ENV['branch']}"
end

if ENV['project'] == 'ec-admin'
  set :linked_files, %w{.env}
end

namespace :deploy do
  # For Laravel applications
  laravel_5_projects = [
    'ec-admin'
  ]
  desc "laravel"
  task :laravel do
    if laravel_5_projects.include? ENV['project']
      on roles(:web) do |host|
        execute "cd #{release_path}; composer install --no-dev --no-progress --no-interaction --quiet"
        execute "chmod 777 #{release_path}/bootstrap/cache"
      end
    end
  end
  after :updated, :laravel

  # Clear opcode cache
  opcache_projects = [
    'ec-admin'
  ]
  desc "opcache"
  task :opcache do
    if opcache_projects.include? ENV['project']
      on roles(:web) do |host|
        execute "sudo service php-fpm reload"
      end
    end
  end
  after :published, :opcache
end
