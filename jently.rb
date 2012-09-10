require './lib/git.rb'
require './lib/github.rb'
require './lib/jenkins.rb'
require './lib/helpers.rb'

def test_pull_request(pull_request_id)
  config = ConfigFile.read
  pull_request = Github.get_pull_request(pull_request_id)

  is_test_required = PullRequestsData.is_test_required(pull_request)
  PullRequestsData.update(pull_request)

  if is_test_required
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
        job_id = Jenkins.start_job
        state = Jenkins.wait_on_job(job_id)
        Github.set_pull_request_status(pull_request_id, state)
      end

      timeout = thr.join(config[:jenkins_job_timeout_seconds]).nil?
      Github.set_pull_request_status(pull_request_id, {:status => 'error', :description => 'Job timed out.'}) if timeout
    end
  end
end

while true
  config = ConfigFile.read
  open_pull_requests_ids = Github.get_open_pull_requests_ids
  PullRequestsData.remove_dead_pull_requests(open_pull_requests_ids)

  open_pull_requests_ids.each do |pull_request_id|
    begin
      test_pull_request(pull_request_id)
    rescue => e
      Github.set_pull_request_status(pull_request_id, {:status => 'error', :description => "Error: #{e.message}"})
    end
  end
  sleep config[:github_polling_interval_seconds]
end
