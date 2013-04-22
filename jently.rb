require './lib/git.rb'
require './lib/github.rb'
require './lib/jenkins.rb'
require './lib/helpers/logger'
require './lib/helpers/repository'
require './lib/helpers/config_file'
require './lib/helpers/pull_requests_data'

def test_pull_request(pull_request_id)
  begin
    config = ConfigFile.read
    pull_request = PullRequestsData.read[pull_request_id]

    if pull_request[:mergeable] == false
      Github.set_pull_request_status(pull_request_id, {:status => 'failure', :description => 'Unmergeable pull request.'})
    end

    if pull_request[:mergeable] == true
      Git.clone_repository if !Repository.exists_locally
      Git.delete_local_testing_branch
      Git.delete_remote_testing_branch
      Git.create_local_testing_branch(pull_request)
      Git.push_local_testing_branch_to_remote

      Jenkins.wait_for_idle_executor

      thr = Thread.new do
        Github.set_pull_request_status(pull_request_id, {:status => 'pending', :description => 'Started work on pull request.'})
        job_id = Jenkins.start_job(pull_request_id)
        state = Jenkins.wait_on_job(job_id)
        Github.set_pull_request_status(pull_request_id, state)
      end

      timeout = thr.join(config[:jenkins_job_timeout_seconds]).nil?
      Github.set_pull_request_status(pull_request_id, {:status => 'error', :description => 'Job timed out.'}) if timeout
    end
  rescue => e
    Github.set_pull_request_status(pull_request_id, {:status => 'error', :description => 'An error has occurred. This pull request will be automatically rescheduled for testing.'})
    Logger.log('Error when testing pull request', e)
  end
end

while true
  begin
    config = ConfigFile.read
    open_pull_requests_ids = Github.get_open_pull_requests_ids
    PullRequestsData.remove_dead_pull_requests(open_pull_requests_ids)

    open_pull_requests_ids.each do |pull_request_id|
      pull_request = Github.get_pull_request(pull_request_id)
      if PullRequestsData.has_outdated_success_status(pull_request)
        Github.set_pull_request_status(pull_request[:id], {:status => 'success', :description => "This has been rescheduled for testing as the '#{pull_request[:base_branch]}' branch has been updated."})
      end
      PullRequestsData.update(pull_request)
    end

    pull_request_id_to_test = PullRequestsData.get_pull_request_id_to_test
    test_pull_request(pull_request_id_to_test) if !pull_request_id_to_test.nil?

    sleep config[:github_polling_interval_seconds]
  rescue => e
    Logger.log('Error in main loop', e)
  end
end
