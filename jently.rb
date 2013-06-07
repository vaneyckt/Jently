require './lib/git.rb'
require './lib/core.rb'
require './lib/github.rb'
require './lib/jenkins.rb'
require './lib/helpers/github_client.rb'
require './lib/helpers/logger.rb'
require './lib/helpers/repository.rb'
require './lib/helpers/config_file.rb'
require './lib/helpers/pull_requests_data.rb'

while true
  begin
    config = ConfigFile.read
    Core.poll_pull_requests_and_queue_next_job
    sleep config[:github_polling_interval_seconds]
  rescue => e
    Logger.log('Error in main loop', e)
  end
end
