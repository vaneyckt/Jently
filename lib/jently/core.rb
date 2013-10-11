module Core
  module_function

  def config
    ConfigFile.read(Jently.config_filename)
  end

  def test_pull_request(id)
    begin
      pull_request = PullRequestsData.read[id]
      mergeable    = pull_request[:mergeable]

      Log.log("Testing pull request #{id}", :level => :debug)

      if mergeable
        Jenkins.wait_for_idle_executor

        thread = Thread.new do
          attrs = {
            :status      => 'pending',
            :description => 'Started work on pull request.'
          }
          Github.set_pull_request_status(id, attrs)

          Log.log("Triggering Jenkins build for #{id}")
          job_id = Jenkins.start_job(id)
          Log.log("Waiting for feedback on Jenkins job #{job_id} for pull request #{id}", :level => :debug)
          state  = Jenkins.wait_on_job(job_id)
          Github.set_pull_request_status(id, state)
        end

        interval = config[:jenkins_job_timeout_seconds]
        if thread.join(interval).nil?
          attrs = {
            :status      => 'error',
            :description => 'Job timed out.'
          }
          Github.set_pull_request_status(id, attrs)
        end
      else
        attrs = {
          :status      => 'failure',
          :description => 'Unmergeable pull request.'
        }
        Github.set_pull_request_status(id, attrs)
      end
    rescue => e
      Log.log('Error when testing pull request', e, :level => :error)

      attrs = {
        :status      => 'error',
        :description => 'An error has occurred. This pull request will be automatically rescheduled for testing.'
      }
      Github.set_pull_request_status(id, attrs)
    end
  end

  def poll_pull_requests_and_queue_next_job
    open_pull_requests_ids = Github.get_open_pull_requests_ids
    PullRequestsData.remove_dead_pull_requests(open_pull_requests_ids)

    Log.log("The current open pull requests are #{open_pull_requests_ids.sort.join(', ')}")
    open_pull_requests_ids.each do |pull_request_id|
      pull_request = Github.get_pull_request(pull_request_id)
      if PullRequestsData.outdated_success_status?(pull_request)
        id          = pull_request[:id]
        base_branch = pull_request[:base_branch]
        attrs = {
          :status      => 'success',
          :description => "This has been rescheduled for testing as the '#{base_branch}' branch has been updated."
        }
        Github.set_pull_request_status(id, attrs)
      end
      PullRequestsData.update(pull_request)
    end

    pull_request_id_to_test = PullRequestsData.next
    if pull_request_id_to_test
      test_pull_request(pull_request_id_to_test)
    else
      Log.log("There are no pull requests that require testing")
    end
  end
end
