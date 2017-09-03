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
  desc "Display human readable information"
  task :display_information do
    on roles(:all) do |host|
      info "Application: #{fetch(:application)}"
      if ENV['project']
        info "Project: " + ENV['project']
      end
      info "Fetch code from: #{fetch(:repo_url)}"
      info "Use the Branch: #{fetch(:branch)}"
      info "And deploy to: #{host} #{fetch(:deploy_to)}/#{fetch(:current_dir)}"
    end
  end
  before :starting, :display_information

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

  # Clear broken symlinks
  desc "clear broken symlinks"
  task :clear_broken_symlink do
    on roles(:web) do |host|
      execute "find #{fetch(:deploy_to)} -maxdepth 1 -type l -exec test ! -e {} \\; -delete"
    end
  end
  after :finishing, :clear_broken_symlink

  # refine symlink
  namespace :symlink do
    Rake::Task["release"].clear_actions
    task :release do
      on release_roles :all do
        execute :rm, '-rf', deploy_path + "#{fetch(:current_dir)}"
        execute :ln, '-s', release_path, deploy_path + "#{fetch(:current_dir)}"
      end
    end
  end
end

#check if branch exists
before "deploy:started", :git_repo_check do
  %w{ git:check:repo }.each do |task|
    invoke "#{task}"
  end
end

namespace :git do
  namespace :check do
    desc "Checks source repo for deploy branch."
    task :repo do
      on roles(:all) do |host|
        Rake::Task["git:check"].invoke()

        repo_path = "#{fetch(:deploy_to)}/repo"

        if test "[ -f #{repo_path}/HEAD ]"
          within repo_path do
            execute :git, 'remote', 'set-url', 'origin', fetch(:repo_url)
          end
          if test "git --git-dir=#{repo_path} fetch origin #{fetch(:branch)}"
            info "Remote repo has branch #{fetch(:branch)}"
          else
            error_msg = "There is no remote branch #{fetch(:branch)} available!"
            error error_msg
            throw 'Error: ' + error_msg
          end
        else
            info "Remote repo not created yet"
        end
      end
    end
  end
end
