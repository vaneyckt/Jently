require './lib/git.rb'
require './lib/core.rb'
require './lib/github.rb'
require './lib/jenkins.rb'
require './lib/helpers/logger'
require './lib/helpers/repository'
require './lib/helpers/config_file'
require './lib/helpers/pull_requests_data'

while true
  begin
    config = ConfigFile.read
    Core.poll_pull_requests_and_queue_next_job
    sleep config[:github_polling_interval_seconds]
  rescue => e
    Logger.log('Error in main loop', e)
  end
end
