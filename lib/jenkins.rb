require 'faraday'
require 'faraday_middleware'
require './lib/helpers/logger'
require './lib/helpers/config_file'

module Jenkins
  def Jenkins.wait_for_idle_executor
    config = ConfigFile.read
    while true
      return if get_nb_of_idle_executors >= 1
      sleep config[:jenkins_polling_interval_seconds]
    end
  end

  def Jenkins.get_nb_of_idle_executors
    begin
      config = ConfigFile.read
      connection = new_connection("#{config[:jenkins_url]}/api/json", config)

      response = connection.get do |req|
        req.params[:depth] = 1
        req.params[:tree] = 'assignedLabels[idleExecutors]'
      end
      response.body[:assignedLabels][0][:idleExecutors]
    rescue => e
      Logger.log('Error when getting nb of idle executors', e)
      sleep 5
      retry
    end
  end

  def Jenkins.new_job_id(pull_request_id)
    "#{pull_request_id}-#{(Time.now.to_f * 1000000).to_i}"
  end

  def Jenkins.start_job(pull_request_id)
    begin
      config = ConfigFile.read
      url = "#{config[:jenkins_url]}/job/#{config[:jenkins_job_name]}/buildWithParameters"
      connection = new_connection(url, config, use_json = false)

      job_id = new_job_id(pull_request_id)
      connection.post do |req|
        req.params[:id] = job_id
        req.params[:branch] = config[:testing_branch_name]
        req.params[:repository] = config[:github_ssh_repository]
      end
      job_id
    rescue => e
      Logger.log('Error when starting job', e)
      sleep 5
      retry
    end
  end

  def Jenkins.wait_on_job(job_id)
    config = ConfigFile.read
    while true
      state = get_job_state(job_id)
      return state if !state.nil?
      sleep config[:jenkins_polling_interval_seconds]
    end
  end

  def Jenkins.get_job_state(job_id)
    begin
      config = ConfigFile.read
      connection = new_connection("#{config[:jenkins_url]}/job/#{config[:jenkins_job_name]}/api/json", config)

      response = connection.get do |req|
        req.params[:depth] = 1
        req.params[:tree] = 'builds[actions[parameters[name,value]],result,url]'
      end

      state = nil
      response.body[:builds].each do |build|
        begin
          if build[:actions][0][:parameters][2][:value] == job_id
            state = {:status => 'success', :url => build[:url]} if build[:result] == 'SUCCESS'
            state = {:status => 'failure', :url => build[:url]} if build[:result] == 'UNSTABLE'
            state = {:status => 'failure', :url => build[:url]} if build[:result] == 'FAILURE'
          end
        rescue
        end
      end
      state
    rescue => e
      Logger.log('Error when getting job state', e)
      sleep 5
      retry
    end
  end

  def self.new_connection(url, config, use_json = true)
    connection = Faraday.new(:url => url) do |c|
      c.use Faraday::Request::UrlEncoded
      c.use FaradayMiddleware::FollowRedirects
      c.use Faraday::Adapter::NetHttp
      if use_json
        c.use FaradayMiddleware::Mashify
        c.use FaradayMiddleware::ParseJson
      end
    end

    if config.has_key?(:jenkins_login) && config.has_key?(:jenkins_password)
      connection.basic_auth config[:jenkins_login], config[:jenkins_password]
    end

    connection
  end
end
