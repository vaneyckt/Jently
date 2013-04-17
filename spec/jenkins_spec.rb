require 'spec_helper'

describe Jenkins do

  before do
    Jenkins.stub(:sleep) # don't actually want to sleep during our test runs
    Logger.stub(:log)
  end

  describe '.get_nb_of_idle_executors' do
    let(:jenkins_url) { 'http://valid.jenkins.url' }
    let(:api_url) { "#{jenkins_url}/api/json?depth=1&tree=assignedLabels%5BidleExecutors%5D" }
    let(:config_data) { { :jenkins_url => jenkins_url } }
    let(:idle_executors) { 5 }
    let(:json_response) { '{"assignedLabels": { "0": {"idleExecutors": ' + idle_executors.to_s + '} } }' }

    before do
      ConfigFile.stub(:read).and_return( config_data )
      stub_request(:get, api_url).to_return(:status => 200, :body => json_response, :headers => {})
    end

    it 'sends a request to the Jenkins api' do
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
end
