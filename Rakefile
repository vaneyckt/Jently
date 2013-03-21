require 'bundler/setup'
require 'rake'

desc "Start the server."
task :start do
  sh 'ruby jently_control.rb start'
end

desc "Stop the server."
task :stop do
  rm pid_file
  sh 'ruby jently_control.rb stop'
end

task :default do
  to_run = if File.exists? pid_file
    'stop'
  else
    'start'
  end

  Rake::Task[to_run].invoke
end

def pid_file
  File.expand_path '../jently.pid', __FILE__
end
