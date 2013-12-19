require 'spec_helper'

describe Github do
  let(:github_login)       { 'valid_login' }
  let(:github_password)    { 'valid_password' }
  let(:github_oauth_token) { 'valid_oauth_token' }
  let(:repo_id)            { 'valid_repo/id' }

  before do
    Github.stub(:sleep)
    Log.stub(:log)
    ConfigFile.stub(:read).and_return(config_data)
    Repository.stub(:get_id).and_return(repo_id)
  end

  context 'when the github authentication is performed with a login and password' do
    let(:config_data) { { :github_login => github_login, :github_password => github_password } }

    describe '.get_open_pull_requests_ids' do
      let(:octokit_client)      { mock(Octokit::Client) }
      let(:pull_request_number) { 1234 }
      let(:pull_request)        { mock('PullRequest', :number => pull_request_number) }

      before do
        Octokit::Client.stub(:new).and_return(octokit_client)
        octokit_client.stub(:pull_requests).and_return([pull_request])
      end

      it 'instantiates a new Octokit client, specifying credentials from the config file' do
        expected_params = { :login => github_login, :password => github_password }
        Octokit::Client.should_receive(:new).with( hash_including(expected_params) ).and_return( octokit_client )

        Github.get_open_pull_requests_ids
      end

      it 'requests all open pull requests from the client, specifying the repository id' do
        octokit_client.should_receive(:pull_requests).with(repo_id, 'open').and_return([pull_request])

        Github.get_open_pull_requests_ids
      end

      it 'returns the pull request number of each open pull request' do
        Github.get_open_pull_requests_ids.should eql [pull_request_number]
      end

      context 'when a request fails' do
        let(:octokit_error) { StandardError.new('some octokit failure') }

        before do
          octokit_call_counter = 0
          octokit_client.stub(:pull_requests) do
            octokit_call_counter += 1
            raise octokit_error if octokit_call_counter < 2
            [pull_request]
          end
        end

        it 'logs the failure' do
          Log.should_receive(:log).with(/Error.*open pull request.*ids.*/, octokit_error)

          Github.get_open_pull_requests_ids
        end

        it 'retries the request after a 5 second delay' do
          Octokit::Client.should_receive(:new).twice.and_return(octokit_client, octokit_client)
          octokit_client.should_receive(:pull_requests).twice
          Github.should_receive(:sleep).with(5)

          Github.get_open_pull_requests_ids
        end
      end
    end

    describe '.get_pull_request' do
      let(:head)      { mock('Commit', :sha => 'abcdef', :ref => 'valid/ref') }
      let(:base)      { mock('Commit', :sha => 'ghijkl', :ref => 'other/valid/ref') }
      let(:base_last) { mock('Commit', :sha => 'mnopqr', :ref => 'last/base/ref') }

      let(:pull_request_id) { 1234 }
      let(:pull_request)    { mock('PullRequest', :number => pull_request_id, :head => head, :base => base, :mergeable => true, :merged => false) }

      let(:octokit_client) { mock(Octokit::Client) }

      before do
        Octokit::Client.stub(:new).and_return(octokit_client)
        octokit_client.stub(:pull_request).and_return(pull_request)
        octokit_client.stub(:statuses).and_return([])
        octokit_client.stub(:commits).and_return([base_last, base])
      end

      it 'instantiates a new Octokit client, specifying credentials from the config file' do
        expected_params = { :login => github_login, :password => github_password }
        Octokit::Client.should_receive(:new).with( hash_including(expected_params) ).and_return( octokit_client )

        Github.get_pull_request(pull_request_id)
      end

      it 'requests a pull request from the client, specifying the repository id and pull request id' do
        octokit_client.should_receive(:pull_request).with(repo_id, pull_request_id).and_return(pull_request)

        Github.get_pull_request(pull_request_id)
      end

      it 'requests client statuses, specifying the repository id and sha of the pull request head' do
        octokit_client.should_receive(:statuses).with(repo_id, head.sha).and_return([])

        Github.get_pull_request(pull_request_id)
      end

      it 'requests a list of commits from the client, specifying the repository id and the ref of the base branch' do
        octokit_client.should_receive(:commits).with(repo_id, base.ref).and_return([base_last, base])

        Github.get_pull_request(pull_request_id)
      end

      it 'creates and returns a hash populated with attributes of the pull request ' do
        result = Github.get_pull_request(pull_request_id)
        result[:id].should eql pull_request.number
        result[:merged].should eql pull_request.merged
        result[:mergeable].should eql pull_request.mergeable
        result[:head_branch].should eql head.ref
        result[:head_sha].should eql head.sha
        result[:base_branch].should eql base.ref
        result[:base_sha].should eql base_last.sha
      end

      context 'when there are no statuses for the current head commit' do
        it 'returns a hash with status attribute set to undefined' do
          octokit_client.stub(:statuses).and_return([])

          result = Github.get_pull_request(pull_request_id)

          result[:status].should eql 'undefined'
        end
      end

      context 'when there are statuses for the current head commit' do
        it 'returns a hash with status attribute set to the state of the most recent status' do
          status_1 = mock('CommitStatus', :state => 'amazing', :updated_at => '2013-10-02 03:11:57 UTC' )
          status_2 = mock('CommitStatus', :state => 'terrible', :updated_at => '2013-10-02 03:11:58 UTC')
          octokit_client.stub(:statuses).and_return([status_1, status_2])

          result = Github.get_pull_request(pull_request_id)

          result[:status].should eql status_2.state
        end
      end

      context 'when a request fails' do
        let(:octokit_error) { StandardError.new('some octokit failure') }

        before do
          octokit_call_counter = 0
          octokit_client.stub(:pull_request) do
            octokit_call_counter += 1
            raise octokit_error if octokit_call_counter < 2
            pull_request
          end
        end

        it 'logs the failure' do
          Log.should_receive(:log).with('Error when getting pull request', octokit_error)

          Github.get_pull_request(pull_request_id)
        end

        it 'retries the request after a 5 second delay' do
          Octokit::Client.should_receive(:new).twice.and_return(octokit_client, octokit_client)
          octokit_client.should_receive(:pull_request).twice
          Github.should_receive(:sleep).with(5)

          Github.get_pull_request(pull_request_id)
        end
      end
    end

    describe '.set_pull_request_status' do
      let(:pull_request_id) { 1234 }
      let(:octokit_client)  { mock(Octokit::Client) }

      let(:success_state)   { { :url => 'http://valid.url', :status => 'success', :description => 'valid description' } }
      let(:undefined_state) { { :url => nil, :status => 'undefined', :description => nil } }
      let(:failed_state)    { { :status => 'failure' } }

      let(:head_sha)           { 'abcdefg' }
      let(:pull_requests_data) { { pull_request_id => {:head_sha => head_sha} } }

      before do
        Octokit::Client.stub(:new).and_return(octokit_client)
        PullRequestsData.stub(:read).and_return(pull_requests_data)
        PullRequestsData.stub(:update_status)
        PullRequestsData.stub(:reset)
        octokit_client.stub(:create_status)
      end

      it 'instantiates a new Octokit client, specifying credentials from the config file' do
        expected_params = { :login => github_login, :password => github_password }
        Octokit::Client.should_receive(:new).with( hash_including(expected_params) ).and_return( octokit_client )

        Github.set_pull_request_status(pull_request_id, success_state)
      end

      it 'tells the OctoKit client to create a new status, specifying repo id, head sha, and build status' do
        octokit_client.should_receive(:create_status).with(repo_id, head_sha, 'success', anything())

        Github.set_pull_request_status(pull_request_id, success_state)
      end

      context 'when the specified state has a non-nil jenkins url' do
        it 'includes the jenkins url in the options passed to client create_status' do
          opts = {:description => success_state[:description]}
          octokit_client.should_receive(:create_status).with( anything(), anything(), anything(), hash_including(opts) )

          Github.set_pull_request_status(pull_request_id, success_state)
        end
      end

      context 'when the specified state has a non-nil description' do
        it 'includes the description in the options passed to client create_status' do
          opts = {:target_url => success_state[:url]}
          octokit_client.should_receive(:create_status).with( anything(), anything(), anything(), hash_including(opts) )

          Github.set_pull_request_status(pull_request_id, success_state)
        end
      end

      context 'when the specified state has a nil jenkins url or descritpion' do
        it 'does not include a url or description keys in the options passed to client create_status' do
          octokit_client.should_receive(:create_status).with( anything(), anything(), anything(), {} )

          Github.set_pull_request_status(pull_request_id, undefined_state)
        end
      end

      it 'tells PullRequestsData to update_status' do
        PullRequestsData.should_receive(:update_status).with(pull_request_id, success_state[:status])

        Github.set_pull_request_status(pull_request_id, success_state)
      end

      context 'when the specified state has a status that is neither success or failure' do
        it 'does not tell PullRequestsData to reset priority and test required' do
          PullRequestsData.should_not_receive(:reset)

          Github.set_pull_request_status(pull_request_id, undefined_state)
        end
      end

      context 'when the specified state has a status of success' do
        it 'tells PullRequestsData to reset priority and test required' do
          PullRequestsData.should_receive(:reset).with(pull_request_id)

          Github.set_pull_request_status(pull_request_id, success_state)
        end
      end

      context 'when the specified state has a status of failure' do
        it 'tells PullRequestsData to reset priority and test required' do
          PullRequestsData.should_receive(:reset).with(pull_request_id)

          Github.set_pull_request_status(pull_request_id, failed_state)
        end
      end

      context 'when a request fails' do
        let(:octokit_error) { StandardError.new('some octokit failure') }

        before do
          octokit_call_counter = 0
          octokit_client.stub(:create_status) do
            octokit_call_counter += 1
            raise octokit_error if octokit_call_counter < 2
          end
        end

        it 'logs the failure' do
          Log.should_receive(:log).with('Error when setting pull request status', octokit_error)

          Github.set_pull_request_status(pull_request_id, success_state)
        end

        it 'retries the request after a 5 second delay' do
          Octokit::Client.should_receive(:new).twice.and_return(octokit_client, octokit_client)
          octokit_client.should_receive(:create_status).twice
          Github.should_receive(:sleep).with(5)

          Github.set_pull_request_status(pull_request_id, success_state)
        end
      end
    end
  end

  context 'when the github authentication is performed with a login and oauth token' do
    let(:config_data) { { :github_login => github_login, :github_oauth_token => github_oauth_token } }

    describe '.get_open_pull_requests_ids' do
      let(:octokit_client)      { mock(Octokit::Client) }
      let(:pull_request_number) { 1234 }
      let(:pull_request)        { mock('PullRequest', :number => pull_request_number) }

      before do
        Octokit::Client.stub(:new).and_return(octokit_client)
        octokit_client.stub(:pull_requests).and_return([pull_request])
      end

      it 'instantiates a new Octokit client, specifying credentials from the config file' do
        expected_params = { :login => github_login, :oauth_token => github_oauth_token }
        Octokit::Client.should_receive(:new).with( hash_including(expected_params) ).and_return( octokit_client )

        Github.get_open_pull_requests_ids
      end

      it 'requests all open pull requests from the client, specifying the repository id' do
        octokit_client.should_receive(:pull_requests).with(repo_id, 'open').and_return([pull_request])

        Github.get_open_pull_requests_ids
      end

      it 'returns the pull request number of each open pull request' do
        Github.get_open_pull_requests_ids.should eql [pull_request_number]
      end

      context 'when a request fails' do
        let(:octokit_error) { StandardError.new('some octokit failure') }

        before do
          octokit_call_counter = 0
          octokit_client.stub(:pull_requests) do
            octokit_call_counter += 1
            raise octokit_error if octokit_call_counter < 2
            [pull_request]
          end
        end

        it 'logs the failure' do
          Log.should_receive(:log).with(/Error.*open pull request.*ids.*/, octokit_error)

          Github.get_open_pull_requests_ids
        end

        it 'retries the request after a 5 second delay' do
          Octokit::Client.should_receive(:new).twice.and_return(octokit_client, octokit_client)
          octokit_client.should_receive(:pull_requests).twice
          Github.should_receive(:sleep).with(5)

          Github.get_open_pull_requests_ids
        end
      end
    end

    describe '.get_pull_request' do
      let(:head)      { mock('Commit', :sha => 'abcdef', :ref => 'valid/ref') }
      let(:base)      { mock('Commit', :sha => 'ghijkl', :ref => 'other/valid/ref') }
      let(:base_last) { mock('Commit', :sha => 'mnopqr', :ref => 'last/base/ref') }

      let(:pull_request_id) { 1234 }
      let(:pull_request)    { mock('PullRequest', :number => pull_request_id, :head => head, :base => base, :mergeable => true, :merged => false) }

      let(:octokit_client) { mock(Octokit::Client) }

      before do
        Octokit::Client.stub(:new).and_return(octokit_client)
        octokit_client.stub(:pull_request).and_return(pull_request)
        octokit_client.stub(:statuses).and_return([])
        octokit_client.stub(:commits).and_return([base_last, base])
      end

      it 'instantiates a new Octokit client, specifying credentials from the config file' do
        expected_params = { :login => github_login, :oauth_token => github_oauth_token }
        Octokit::Client.should_receive(:new).with( hash_including(expected_params) ).and_return( octokit_client )

        Github.get_pull_request(pull_request_id)
      end

      it 'requests a pull request from the client, specifying the repository id and pull request id' do
        octokit_client.should_receive(:pull_request).with(repo_id, pull_request_id).and_return(pull_request)

        Github.get_pull_request(pull_request_id)
      end

      it 'requests client statuses, specifying the repository id and sha of the pull request head' do
        octokit_client.should_receive(:statuses).with(repo_id, head.sha).and_return([])

        Github.get_pull_request(pull_request_id)
      end

      it 'requests a list of commits from the client, specifying the repository id and the ref of the base branch' do
        octokit_client.should_receive(:commits).with(repo_id, base.ref).and_return([base_last, base])

        Github.get_pull_request(pull_request_id)
      end

      it 'creates and returns a hash populated with attributes of the pull request ' do
        result = Github.get_pull_request(pull_request_id)
        result[:id].should eql pull_request.number
        result[:merged].should eql pull_request.merged
        result[:mergeable].should eql pull_request.mergeable
        result[:head_branch].should eql head.ref
        result[:head_sha].should eql head.sha
        result[:base_branch].should eql base.ref
        result[:base_sha].should eql base_last.sha
      end

      context 'when there are no statuses for the current head commit' do
        it 'returns a hash with status attribute set to undefined' do
          octokit_client.stub(:statuses).and_return([])

          result = Github.get_pull_request(pull_request_id)

          result[:status].should eql 'undefined'
        end
      end

      context 'when there are statuses for the current head commit' do
        it 'returns a hash with status attribute set to the state of the most recent status' do
          status_1 = mock('CommitStatus', :state => 'amazing', :updated_at => '2013-10-02 03:11:57 UTC' )
          status_2 = mock('CommitStatus', :state => 'terrible', :updated_at => '2013-10-02 03:11:58 UTC')
          octokit_client.stub(:statuses).and_return([status_1, status_2])

          result = Github.get_pull_request(pull_request_id)

          result[:status].should eql status_2.state
        end
      end

      context 'when a request fails' do
        let(:octokit_error) { StandardError.new('some octokit failure') }

        before do
          octokit_call_counter = 0
          octokit_client.stub(:pull_request) do
            octokit_call_counter += 1
            raise octokit_error if octokit_call_counter < 2
            pull_request
          end
        end

        it 'logs the failure' do
          Log.should_receive(:log).with('Error when getting pull request', octokit_error)

          Github.get_pull_request(pull_request_id)
        end

        it 'retries the request after a 5 second delay' do
          Octokit::Client.should_receive(:new).twice.and_return(octokit_client, octokit_client)
          octokit_client.should_receive(:pull_request).twice
          Github.should_receive(:sleep).with(5)

          Github.get_pull_request(pull_request_id)
        end
      end
    end

    describe '.set_pull_request_status' do
      let(:pull_request_id) { 1234 }
      let(:octokit_client)  { mock(Octokit::Client) }

      let(:success_state)   { { :url => 'http://valid.url', :status => 'success', :description => 'valid description' } }
      let(:undefined_state) { { :url => nil, :status => 'undefined', :description => nil } }
      let(:failed_state)    { { :status => 'failure' } }

      let(:head_sha)           { 'abcdefg' }
      let(:pull_requests_data) { { pull_request_id => {:head_sha => head_sha} } }

      before do
        Octokit::Client.stub(:new).and_return(octokit_client)
        PullRequestsData.stub(:read).and_return(pull_requests_data)
        PullRequestsData.stub(:update_status)
        PullRequestsData.stub(:reset)
        octokit_client.stub(:create_status)
      end

      it 'instantiates a new Octokit client, specifying credentials from the config file' do
        expected_params = { :login => github_login, :oauth_token => github_oauth_token }
        Octokit::Client.should_receive(:new).with( hash_including(expected_params) ).and_return( octokit_client )

        Github.set_pull_request_status(pull_request_id, success_state)
      end

      it 'tells the OctoKit client to create a new status, specifying repo id, head sha, and build status' do
        octokit_client.should_receive(:create_status).with(repo_id, head_sha, 'success', anything())

        Github.set_pull_request_status(pull_request_id, success_state)
      end

      context 'when the specified state has a non-nil jenkins url' do
        it 'includes the jenkins url in the options passed to client create_status' do
          opts = {:description => success_state[:description]}
          octokit_client.should_receive(:create_status).with( anything(), anything(), anything(), hash_including(opts) )

          Github.set_pull_request_status(pull_request_id, success_state)
        end
      end

      context 'when the specified state has a non-nil description' do
        it 'includes the description in the options passed to client create_status' do
          opts = {:target_url => success_state[:url]}
          octokit_client.should_receive(:create_status).with( anything(), anything(), anything(), hash_including(opts) )

          Github.set_pull_request_status(pull_request_id, success_state)
        end
      end

      context 'when the specified state has a nil jenkins url or descritpion' do
        it 'does not include a url or description keys in the options passed to client create_status' do
          octokit_client.should_receive(:create_status).with( anything(), anything(), anything(), {} )

          Github.set_pull_request_status(pull_request_id, undefined_state)
        end
      end

      it 'tells PullRequestsData to update_status' do
        PullRequestsData.should_receive(:update_status).with(pull_request_id, success_state[:status])

        Github.set_pull_request_status(pull_request_id, success_state)
      end

      context 'when the specified state has a status that is neither success or failure' do
        it 'does not tell PullRequestsData to reset priority and test required' do
          PullRequestsData.should_not_receive(:reset)

          Github.set_pull_request_status(pull_request_id, undefined_state)
        end
      end

      context 'when the specified state has a status of success' do
        it 'tells PullRequestsData to reset priority and test required' do
          PullRequestsData.should_receive(:reset).with(pull_request_id)

          Github.set_pull_request_status(pull_request_id, success_state)
        end
      end

      context 'when the specified state has a status of failure' do
        it 'tells PullRequestsData to reset priority and test required' do
          PullRequestsData.should_receive(:reset).with(pull_request_id)

          Github.set_pull_request_status(pull_request_id, failed_state)
        end
      end

      context 'when a request fails' do
        let(:octokit_error) { StandardError.new('some octokit failure') }

        before do
          octokit_call_counter = 0
          octokit_client.stub(:create_status) do
            octokit_call_counter += 1
            raise octokit_error if octokit_call_counter < 2
          end
        end

        it 'logs the failure' do
          Log.should_receive(:log).with('Error when setting pull request status', octokit_error)

          Github.set_pull_request_status(pull_request_id, success_state)
        end

        it 'retries the request after a 5 second delay' do
          Octokit::Client.should_receive(:new).twice.and_return(octokit_client, octokit_client)
          octokit_client.should_receive(:create_status).twice
          Github.should_receive(:sleep).with(5)

          Github.set_pull_request_status(pull_request_id, success_state)
        end
      end
    end
  end
end
