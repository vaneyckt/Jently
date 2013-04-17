require 'spec_helper'

describe Github do
  let(:github_login)    { 'valid_login' }
  let(:github_password) { 'valid_password' }
  let(:repo_id)         { 'valid_repo/id' }

  let(:config_data) { { :github_login => github_login, :github_password => github_password } }

  before do
    Github.stub(:sleep)
    ConfigFile.stub(:read).and_return(config_data)
    Repository.stub(:get_id).and_return(repo_id)
  end

  describe '.get_open_pull_requests_ids' do
    let(:octokit_client) { mock(Octokit::Client) }
    let(:pull_request_number) { 1234 }
    let(:pull_request) { mock('PullRequest', :number => pull_request_number) }

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
        Logger.should_receive(:log).with(/Error.*open pull request.*ids.*/, octokit_error)

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
end
