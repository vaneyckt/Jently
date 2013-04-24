require 'spec_helper'

describe Jently do
  describe '.poll_pull_requests_and_queue_next_job' do
    let(:pull_request_id) { 1234 }
    let(:base_branch) { 'abc_branch' }
    let(:pull_request) { { :id => pull_request_id, :base_branch => base_branch } }

    before do
      Github.stub(:get_open_pull_requests_ids).and_return([pull_request_id])
      PullRequestsData.stub(:remove_dead_pull_requests)
      Github.stub(:get_pull_request).and_return(pull_request)
      PullRequestsData.stub(:outdated_success_status?).and_return(false)
      Github.stub(:set_pull_request_status)
      PullRequestsData.stub(:update)
      PullRequestsData.stub(:get_pull_request_id_to_test).and_return(nil)
      Jently.stub(:test_pull_request)
    end

    it 'retrieves a list of open pull request ids from Github' do
      Github.should_receive(:get_open_pull_requests_ids).and_return([pull_request_id])

      Jently.poll_pull_requests_and_queue_next_job
    end

    it 'tells PullRequestsData to remove dead pull requests, specifing open pull request ids' do
      PullRequestsData.should_receive(:remove_dead_pull_requests).with([pull_request_id])

      Jently.poll_pull_requests_and_queue_next_job
    end

    it 'retrieves detailed pull request information from Github for each open pull request' do
      Github.should_receive(:get_pull_request).with(pull_request_id).and_return(pull_request)

      Jently.poll_pull_requests_and_queue_next_job
    end

    context 'when an open pull request status has changed from the last stored status' do
      it 'tells Github to mark the pull request as being scheduled for testing' do
        PullRequestsData.should_receive(:outdated_success_status?).with(pull_request).and_return(true)

        params = {:status => 'success'}
        Github.should_receive(:set_pull_request_status).with( pull_request_id, hash_including(params) )

        Jently.poll_pull_requests_and_queue_next_job
      end
    end

    it 'updates the stored pull request data for each open pull request' do
      PullRequestsData.should_receive(:update).with(pull_request)

      Jently.poll_pull_requests_and_queue_next_job
    end

    context 'when there is a pull request that needs testing' do
      it 'triggers a new test for that pull request' do
        PullRequestsData.stub(:get_pull_request_id_to_test).and_return(pull_request_id)
        Jently.should_receive(:test_pull_request).with(pull_request_id)

        Jently.poll_pull_requests_and_queue_next_job
      end
    end

    context 'when there is no pull request that needs testing' do
      it 'does not trigger any new pull request tests' do
        PullRequestsData.stub(:get_pull_request_id_to_test).and_return(nil)
        Jently.should_not_receive(:test_pull_request)

        Jently.poll_pull_requests_and_queue_next_job
      end
    end
  end

  describe '.test_pull_request' do
    let(:pull_request_id) { 1234 }
    let(:jenkins_timeout) { 0.05 }
    let(:job_id) { 456789 }
    let(:pull_request) { { :id => pull_request_id, :mergeable => true } }
    let(:job_state) { { :status => 'success' } }

    before do
      ConfigFile.stub(:read).and_return(:jenkins_job_timeout_seconds => jenkins_timeout)
      Github.stub(:set_pull_request_status)
      PullRequestsData.stub(:read).and_return(pull_request_id => pull_request)
      Git.stub(:setup_testing_branch)
      Jenkins.stub(:wait_for_idle_executor)
      Jenkins.stub(:start_job).and_return(job_id)
      Jenkins.stub(:wait_on_job).and_return(job_state)
      Logger.stub(:log)
    end

    it 'retrieves the stored pull request for the specified pull request id' do
      PullRequestsData.should_receive(:read).and_return(pull_request_id => pull_request)

      Jently.test_pull_request(pull_request_id)
    end

    context 'when the pull reqeust is mergeable' do
      it 'tells Git to set up the testing branch' do
        Git.should_receive(:setup_testing_branch).with(pull_request)

        Jently.test_pull_request(pull_request_id)
      end

      it 'waits for an idle executor on Jenkins' do
        Jenkins.should_receive(:wait_for_idle_executor)

        Jently.test_pull_request(pull_request_id)
      end

      it 'tells Github to mark the pull request status as pending' do
        params = {:status => 'pending'}
        Github.should_receive(:set_pull_request_status).with( pull_request_id, hash_including(params) )

        Jently.test_pull_request(pull_request_id)
      end

      it 'retrieves a job_id by telling Jenkins to start the job' do
        Jenkins.should_receive(:start_job).with(pull_request_id).and_return(job_id)

        Jently.test_pull_request(pull_request_id)
      end

      it 'waits for Jenkins to report a state for the job' do
        Jenkins.should_receive(:wait_on_job).with(job_id).and_return(job_state)

        Jently.test_pull_request(pull_request_id)
      end

      it 'tells Github to mark the pull request status as the state returned by Jenkins' do
        Github.should_receive(:set_pull_request_status).with( pull_request_id, hash_including(job_state) )

        Jently.test_pull_request(pull_request_id)
      end

      context 'when the Jenkins job takes less time than the jenkins_job_timeout_seconds value' do
        it 'does not tell Github to mark the pull request status as timed out' do
          Jenkins.stub(:wait_on_job) do |job|
            sleep (jenkins_timeout - 0.01)
            job_state
          end
          params = {:status => 'error', :description => 'Job timed out.'}
          Github.should_not_receive(:set_pull_request_status).with( pull_request_id, hash_including(params) )

          Jently.test_pull_request(pull_request_id)
        end
      end

      context 'when the Jenkins job takes longer than the jenkins_job_timeout_seconds value' do
        it 'tells Github to mark the pull request status as timed out' do
          Jenkins.stub(:wait_on_job) do |job|
            sleep (jenkins_timeout + 0.001)
            job_state
          end
          params = {:status => 'error', :description => 'Job timed out.'}
          Github.should_receive(:set_pull_request_status).with( pull_request_id, hash_including(params) )

          Jently.test_pull_request(pull_request_id)
        end
      end

      context 'when the pull request test fails' do
        let(:error_message) { "expected_messsage" }
        let(:exception) { StandardError.new(error_message) }

        before do
          ConfigFile.stub(:read).and_raise(exception)
        end

        it 'tells Github to mark the pull request status as failed' do
          expected_description = 'An error has occurred. This pull request will be automatically rescheduled for testing.'
          params = {:status => 'error', :description => expected_description}
          Github.should_receive(:set_pull_request_status).with( pull_request_id, hash_including(params) )

          Jently.test_pull_request(pull_request_id)
        end

        it 'logs the error' do
          Logger.should_receive(:log).with(anything(), exception)

          Jently.test_pull_request(pull_request_id)
        end

      end
    end

    context 'when the pull request is not mergeable' do
      it 'tells Github to mark the pull request status as failed' do
        pull_request[:mergeable] = false
        params = {:status => 'failure'}
        Github.should_receive(:set_pull_request_status).with( pull_request_id, hash_including(params) )

        Jently.test_pull_request(pull_request_id)
      end
    end

  end
end
