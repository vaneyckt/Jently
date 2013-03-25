require './lib/git.rb'
require './lib/github.rb'
require './lib/jenkins.rb'
require './lib/helpers.rb'

def test_pull_request(pull_request_id)
  begin
    config = ConfigFile.read
    pull_request = Github.get_pull_request(pull_request_id)
    PullRequestsData.update(pull_request)

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
  rescue => e
    Github.set_pull_request_status(pull_request_id, {:status => 'error'})
    Logger.log('Error when testing pull request', e)
  end
end

def validate_success_status(pull_request_id)
  begin
    pull_request = Github.get_pull_request(pull_request_id)

    if pull_request[:status] == 'success'
      if PullRequestsData.is_success_status_outdated(pull_request)
        Github.set_pull_request_status(pull_request_id, {:status => 'success', :description => "This has been scheduled for retesting as the '#{pull_request[:base_branch]}' branch has been updated."})
      end
    end
  rescue => e
    Logger.log('Error when validating success status', e)
  end
end

while true
  begin
    config = ConfigFile.read
    open_pull_requests_ids = Github.get_open_pull_requests_ids
    PullRequestsData.remove_dead_pull_requests(open_pull_requests_ids)

    pull_request_ids_with_success_status = PullRequestsData.find_pull_request_ids_with_success_status
    pull_request_ids_with_success_status.each do |pull_request_id|
      validate_success_status(pull_request_id)
    end

    pull_request_id_to_test = nil
    open_pull_requests_ids.shuffle.each do |pull_request_id|
      if pull_request_id_to_test.nil?
        pull_request = Github.get_pull_request(pull_request_id)
        pull_request_id_to_test = pull_request_id if PullRequestsData.is_test_required(pull_request)
      end
    end
    test_pull_request(pull_request_id_to_test) if !pull_request_id_to_test.nil?
  rescue => e
    Logger.log('Error in main loop', e)
  end
  sleep config[:github_polling_interval_seconds]
end
