#!/usr/bin/env ruby

# add lib directory to LOAD_PATH
require 'pathname'
lib = Pathname.new(__FILE__).parent.join('lib').to_s
$: << lib

require 'core'
require 'github'
require 'jenkins'
require 'helpers/logger'
require 'helpers/repository'
require 'helpers/config_file'
require 'helpers/pull_requests_data'

while true
  begin
    config = ConfigFile.read
    Core.poll_pull_requests_and_queue_next_job
    sleep config[:github_polling_interval_seconds]
  rescue => e
    Logger.log('Error in main loop', e)
  end
end
