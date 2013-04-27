require './lib/core.rb'
require './lib/helpers/logger'
require './lib/helpers/config_file'

while true
  begin
    config = ConfigFile.read
    Core.poll_pull_requests_and_queue_next_job
    sleep config[:github_polling_interval_seconds]
  rescue => e
    Logger.log('Error in main loop', e)
  end
end
