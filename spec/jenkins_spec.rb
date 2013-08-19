require 'spec_helper'

describe Jenkins do

  let(:jenkins_url) { 'http://valid.jenkins.url' }

  before do
    Jenkins.stub(:sleep) # don't actually want to sleep during our test runs
    Logger.stub(:log)
  end

  describe '.get_nb_of_idle_executors' do
    let(:api_url) { "#{jenkins_url}/api/json?depth=1&tree=assignedLabels%5BidleExecutors%5D&random=#{Time.now.to_i}" }
    let(:config_data) { { :jenkins_url => jenkins_url } }
    let(:idle_executors) { 5 }
    let(:json_response) { '{"assignedLabels": { "0": {"idleExecutors": ' + idle_executors.to_s + '} } }' }

    before do
      ConfigFile.stub(:read).and_return( config_data )
      stub_request(:get, api_url).to_return(:status => 200, :body => json_response, :headers => {})
    end

    it 'sends a GET request to the Jenkins api' do
      thr = Thread.new do
        Jenkins.get_nb_of_idle_executors
        WebMock.should have_requested(:get, api_url)
      end

      thr.join(5).should_not be_nil
    end

    context 'when configured to use an authorized jenkins user' do
      let(:jenkins_login) { 'jenkins_login' }
      let(:jenkins_password) { 'jenkins_password' }
      let(:jenkins_url) { "http://#{jenkins_login}:#{jenkins_password}@valid.jenkins.url" }

      it 'sends a request with basic auth credentials' do
        thr = Thread.new do
          config_data.merge!(:jenkins_login => jenkins_login, :jenkins_password => jenkins_password)
          Jenkins.get_nb_of_idle_executors
          WebMock.should have_requested(:get, api_url)
        end

        thr.join(5).should_not be_nil
      end
    end

    it 'returns the number of executors parsed from the JSON response' do
      thr = Thread.new do
        Jenkins.get_nb_of_idle_executors.should eql idle_executors
      end

      thr.join(5).should_not be_nil
    end

    context 'when a request fails' do
      let(:request_error) { StandardError.new('some faraday failure') }

      before do
        stub_request(:get, api_url).to_raise(request_error).then.
          to_return(:status => 200, :body => json_response, :headers => {})
      end

      it 'logs the failure' do
        thr = Thread.new do
          Logger.should_receive(:log).with(/Error.*idle executors.*/, request_error)
          Jenkins.get_nb_of_idle_executors
        end

        thr.join(5).should_not be_nil
      end

      it 'retries the request after a 5 second delay' do
        thr = Thread.new do
          Jenkins.should_receive(:sleep).with(5)
          Jenkins.get_nb_of_idle_executors
          WebMock.should have_requested(:get, api_url).twice
        end

        thr.join(5).should_not be_nil
      end
    end
  end

  describe '.start_job' do
    let(:pull_request_id) { 123 }
    let(:jenkins_job_name) { 'job_name' }
    let(:testing_branch_name) { 'branch_name' }
    let(:github_ssh_repository) { 'respository' }

    let(:config_data) { { :jenkins_url           => jenkins_url,
                          :jenkins_job_name      => jenkins_job_name,
                          :testing_branch_name   => testing_branch_name,
                          :github_ssh_repository => github_ssh_repository } }

    let(:api_url) { "#{jenkins_url}/job/#{jenkins_job_name}/buildWithParameters" }
    let(:job_id) { "#{pull_request_id}-123456" }

    before do
      ConfigFile.stub(:read).and_return( config_data )
      Jenkins.stub(:new_job_id).and_return(job_id)
      stub_request(:post, /\A#{api_url}.*/).to_return(:status => 200, :headers => {})
    end

    it 'generates and returns a new job id' do
      thr = Thread.new do
        Jenkins.should_receive(:new_job_id).with(pull_request_id).and_return(job_id)
        Jenkins.start_job(pull_request_id).should eql job_id
      end

      thr.join(5).should_not be_nil
    end

    it 'posts to jenkins build job action with params: job name and git repo from config and generated job id' do
      thr = Thread.new do
        expected_params = {:branch => testing_branch_name, :repository => github_ssh_repository, :id => job_id.to_s}
        Jenkins.start_job(pull_request_id)
        WebMock.should have_requested(:post, /\A#{api_url}.*/).with( :query => hash_including(expected_params) )
      end

      thr.join(5).should_not be_nil
    end

    context 'when configured to use an authorized jenkins user' do
      let(:jenkins_login) { 'jenkins_login' }
      let(:jenkins_password) { 'jenkins_password' }
      let(:jenkins_url) { "http://#{jenkins_login}:#{jenkins_password}@valid.jenkins.url" }

      it 'sends a request with basic auth credentials' do
        thr = Thread.new do
          config_data.merge!(:jenkins_login => jenkins_login, :jenkins_password => jenkins_password)
          Jenkins.start_job(pull_request_id)
          WebMock.should have_requested(:post, /\A#{api_url}.*/)
        end

        thr.join(5).should_not be_nil
      end
    end

    context 'when a request fails' do
      let(:request_error) { StandardError.new('some faraday failure') }

      before do
        stub_request(:post, /\A#{api_url}.*/).to_raise(request_error).then.
          to_return(:status => 200, :headers => {})
      end

      it 'logs the failure' do
        thr = Thread.new do
          Logger.should_receive(:log).with(/Error.*starting job.*/, request_error)
          Jenkins.start_job(pull_request_id)
        end

        thr.join(5).should_not be_nil
      end

      it 'retries the request after a 5 second delay' do
        thr = Thread.new do
          Jenkins.should_receive(:sleep).with(5)
          Jenkins.start_job(pull_request_id)
          WebMock.should have_requested(:post, /\A#{api_url}.*/).twice
        end

        thr.join(5).should_not be_nil
      end
    end
  end

  describe '.get_job_state' do
    let(:jenkins_job_name) { 'job_name' }
    let(:api_url) { "#{jenkins_url}/job/#{jenkins_job_name}/api/json" }
    let(:config_data) { { :jenkins_url => jenkins_url, :jenkins_job_name => jenkins_job_name } }

    let(:successful_build_url) { 'http://successful.build.url/' }
    let(:unstable_build_url) { 'http://unstable.build.url/' }
    let(:failed_build_url) { 'http://failed.build.url/' }

    let(:successful_job_id) { '123' }
    let(:unstable_job_id) { '456' }
    let(:failed_job_id) { '789' }

    def generate_json_for_build(job_id, result_status, url)
      { :result => result_status,
        :url => url,
        :actions => [
          { :parameters => [ 'a', 'b', {:key => 'c', :value => job_id} ] }
        ]
      }
    end

    let(:successful_build) { generate_json_for_build(successful_job_id, 'SUCCESS', successful_build_url) }
    let(:unstable_build)   { generate_json_for_build(unstable_job_id, 'UNSTABLE', unstable_build_url) }
    let(:failed_build)     { generate_json_for_build(failed_job_id, 'UNSTABLE', failed_build_url) }

    let(:json_response) { {:builds => [successful_build, unstable_build, failed_build] }.to_json }

    before do
      ConfigFile.stub(:read).and_return( config_data )
      stub_request(:get, /\A#{api_url}.*/).to_return(:status => 200, :body => json_response, :headers => {})
    end

    it 'sends a GET request to the Jenkins api' do
      thr = Thread.new do
        expected_params = {:depth => '1', :tree => 'builds[actions[parameters[name,value]],building,result,url]'}
        Jenkins.get_job_state(successful_job_id)
        WebMock.should have_requested(:get, api_url).with( :query => hash_including(expected_params) )
      end

      thr.join(5).should_not be_nil
    end

    context 'when configured to use an authorized jenkins user' do
      let(:jenkins_login) { 'jenkins_login' }
      let(:jenkins_password) { 'jenkins_password' }
      let(:jenkins_url) { "http://#{jenkins_login}:#{jenkins_password}@valid.jenkins.url" }

      it 'sends a request with basic auth credentials' do
        thr = Thread.new do
          config_data.merge!(:jenkins_login => jenkins_login, :jenkins_password => jenkins_password)
          Jenkins.get_job_state(successful_job_id)
          WebMock.should have_requested(:get, /\A#{api_url}.*/)
        end

        thr.join(5).should_not be_nil
      end
    end

    it 'returns nil when the response does not contain information about the specified job id' do
      thr = Thread.new do
        Jenkins.get_job_state(999).should be_nil
      end

      thr.join(5).should_not be_nil
    end

    context 'when the id of a successful job is specified' do
      it 'returns a state of success and the job url' do
        thr = Thread.new do
          result = Jenkins.get_job_state(successful_job_id)
          result[:status].should eql 'success'
          result[:url].should eql successful_build_url
        end

        thr.join(5).should_not be_nil
      end
    end

    context 'when the id of an unstable job is specified' do
      it 'returns a state of failure and the job url' do
        thr = Thread.new do
          result = Jenkins.get_job_state(unstable_job_id)
          result[:status].should eql 'failure'
          result[:url].should eql unstable_build_url
        end

        thr.join(5).should_not be_nil
      end
    end

    context 'when the id of a failed job is specified' do
      it 'returns a state of failure and the job url' do
        thr = Thread.new do
          result = Jenkins.get_job_state(failed_job_id)
          result[:status].should eql 'failure'
          result[:url].should eql failed_build_url
        end

        thr.join(5).should_not be_nil
      end
    end

    context 'when a request fails' do
      let(:request_error) { StandardError.new('some faraday failure') }

      before do
        stub_request(:get, /\A#{api_url}.*/).to_raise(request_error).then.
          to_return(:status => 200, :body => json_response, :headers => {})
      end

      it 'logs the failure' do
        thr = Thread.new do
          Logger.should_receive(:log).with(/Error.*job state/, request_error)
          Jenkins.get_job_state(successful_job_id)
        end

        thr.join(5).should_not be_nil
      end

      it 'retries the request after a 5 second delay' do
        thr = Thread.new do
          Jenkins.should_receive(:sleep).with(5)
          Jenkins.get_job_state(successful_job_id)
          WebMock.should have_requested(:get, /\A#{api_url}.*/).twice
        end

        thr.join(5).should_not be_nil
      end
    end
  end

  describe '.wait_on_job' do
    let(:jenkins_polling_interval_seconds) { 10 }
    let(:config_data) { { :jenkins_polling_interval_seconds => jenkins_polling_interval_seconds } }
    let(:job_id) { '456' }
    let(:state) { 'valid state' }

    before do
      ConfigFile.stub(:read).and_return( config_data )
    end

    it 'returns result of Jenkins.get_job_state, passing in the specified job id' do
      thr = Thread.new do
        Jenkins.should_receive(:get_job_state).with(job_id).and_return(state)
        Jenkins.wait_on_job(job_id).should eql state
      end

      thr.join(5).should_not be_nil
    end

    context 'when get_job_state returns nil' do
      before do
        Jenkins.stub(:get_job_state).and_return(nil, state)
      end

      it 'continues to call get_job_state until a non-nil state is returned' do
        thr = Thread.new do
          Jenkins.should_receive(:get_job_state).twice.and_return(nil, state)
          Jenkins.wait_on_job(job_id)
        end

        thr.join(5).should_not be_nil
      end

      it 'waits for the interval specified in the config between retries' do
        thr = Thread.new do
          Jenkins.should_receive(:sleep).with(jenkins_polling_interval_seconds)
          Jenkins.wait_on_job(job_id)
        end

        thr.join(5).should_not be_nil
      end
    end
  end
end
