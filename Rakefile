require 'bundler/setup'
require 'rake'

namespace :server do
  desc "Start the Jently server and write a PID file."
  task :start do
    sh 'ruby jently_control.rb start'
  end

  desc "Stop the Jently server and delete the PID file."
  task :stop do
    sh 'ruby jently_control.rb stop'
  end
end

desc "Check PID file existence, then run the expected task"
task :server do
  action = if File.exists?(File.expand_path '../jently.pid', __FILE__)
    'stop'
  else
    'start'
  end

  Rake::Task["server:#{action}"].invoke
end

namespace :logs do
  desc "Purge and re-create the `log` file."
  task :purge do
    rm 'log' and touch 'log'
  end
end


task :default => :server
