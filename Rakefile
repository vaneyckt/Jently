require 'bundler/setup'
require 'rake'
require 'fileutils'

include FileUtils

task :start do
  sh "ruby jently_control.rb start"
end

task :stop do
  sh "ruby jently_control.rb stop"
  rm pid_file
end

task :toggle do
  task_to_invoke = if File.exists? pid_file
    'stop'
  else
    'start'
  end

  Rake::Task[task_to_invoke].execute
end

task :default => :toggle

def pid_file
  @pid ||= File.expand_path('../jently.pid', __FILE__)
end
