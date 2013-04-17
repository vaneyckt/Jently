require 'spec_helper'

describe Jenkins do

  let(:jenkins_url) { 'http://valid.jenkins.url' }

  before do
    Jenkins.stub(:sleep) # don't actually want to sleep during our test runs
    Logger.stub(:log)
  end

  describe '.get_nb_of_idle_executors' do
    let(:api_url) { "#{jenkins_url}/api/json?depth=1&tree=assignedLabels%5BidleExecutors%5D" }
    let(:config_data) { { :jenkins_url => jenkins_url } }
    let(:idle_executors) { 5 }
    let(:json_response) { '{"assignedLabels": { "0": {"idleExecutors": ' + idle_executors.to_s + '} } }' }

    before do
      ConfigFile.stub(:read).and_return( config_data )
      stub_request(:get, api_url).to_return(:status => 200, :body => json_response, :headers => {})
    end

    it 'sends a GET request to the Jenkins api' do
      Jenkins.get_nb_of_idle_executors

      WebMock.should have_requested(:get, api_url)
    end

    context 'when configured to use an authorized jenkins user' do
      let(:jenkins_login) { 'jenkins_login' }
      let(:jenkins_password) { 'jenkins_password' }
      let(:jenkins_url) { "http://#{jenkins_login}:#{jenkins_password}@valid.jenkins.url" }

      it 'sends a request with basic auth credentials' do
        config_data.merge!(:jenkins_login => jenkins_login, :jenkins_password => jenkins_password)

        Jenkins.get_nb_of_idle_executors

        WebMock.should have_requested(:get, api_url)
      end
    end

    it 'returns the number of executors parsed from the JSON response' do
      Jenkins.get_nb_of_idle_executors.should eql idle_executors
    end

    context 'when a request fails' do
      let(:request_error) { StandardError.new('some faraday failure') }

      before do
        stub_request(:get, api_url).to_raise(request_error).then.
          to_return(:status => 200, :body => json_response, :headers => {})
      end

      it 'logs the failure' do
        Logger.should_receive(:log).with(/Error.*idle executors.*/, request_error)

        Jenkins.get_nb_of_idle_executors
      end

      it 'retries the request after a 5 second delay' do
        Jenkins.should_receive(:sleep).with(5)

        Jenkins.get_nb_of_idle_executors

        WebMock.should have_requested(:get, api_url).twice
      end
    end

  end

  describe '.start_job' do
    let(:jenkins_job_name) { 'job_name' }
    let(:testing_branch_name) { 'branch_name' }
    let(:github_ssh_repository) { 'respository' }

    let(:config_data) { { :jenkins_url           => jenkins_url,
                          :jenkins_job_name      => jenkins_job_name,
                          :testing_branch_name   => testing_branch_name,
                          :github_ssh_repository => github_ssh_repository } }

    let(:api_url) { "#{jenkins_url}/job/#{jenkins_job_name}/buildWithParameters" }
    let(:job_id) { 123456 }

    before do
      ConfigFile.stub(:read).and_return( config_data )
      Jenkins.stub(:new_job_id).and_return(job_id)
      stub_request(:post, /\A#{api_url}.*/).to_return(:status => 200, :headers => {})
    end

    it 'generates and returns a new job id' do
      Jenkins.should_receive(:new_job_id).and_return(job_id)

      Jenkins.start_job.should eql job_id
    end

    it 'posts to jenkins build job action with params: job name and git repo from config and generated job id' do
      expected_params = {:branch => testing_branch_name, :repository => github_ssh_repository, :id => job_id.to_s}

      Jenkins.start_job

      WebMock.should have_requested(:post, /\A#{api_url}.*/).with( :query => hash_including(expected_params) )
    end

    context 'when configured to use an authorized jenkins user' do
      let(:jenkins_login) { 'jenkins_login' }
      let(:jenkins_password) { 'jenkins_password' }
      let(:jenkins_url) { "http://#{jenkins_login}:#{jenkins_password}@valid.jenkins.url" }

      it 'sends a request with basic auth credentials' do
        config_data.merge!(:jenkins_login => jenkins_login, :jenkins_password => jenkins_password)

        Jenkins.start_job

        WebMock.should have_requested(:post, /\A#{api_url}.*/)
      end
    end

    context 'when a request fails' do
      let(:request_error) { StandardError.new('some faraday failure') }

      before do
        stub_request(:post, /\A#{api_url}.*/).to_raise(request_error).then.
          to_return(:status => 200, :headers => {})
      end

      it 'logs the failure' do
        Logger.should_receive(:log).with(/Error.*starting job.*/, request_error)

        Jenkins.start_job
      end

      it 'retries the request after a 5 second delay' do
        Jenkins.should_receive(:sleep).with(5)

        Jenkins.start_job

        WebMock.should have_requested(:post, /\A#{api_url}.*/).twice
      end
    end

  end
end
