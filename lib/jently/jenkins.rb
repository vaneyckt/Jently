require 'faraday'
require 'faraday_middleware'

module Jenkins
  module_function
  def wait_for_idle_executor
    config = ConfigFile.read(Jently.config_filename)
    loop do
      return if idle_executors >= 1
      interval = config[:jenkins_polling_interval_seconds]
      Log.log("Not enough idle Jenkins executors. Sleeping for #{interval}.")
      sleep interval
    end
  end

  def idle_executors
    begin
      config     = ConfigFile.read(Jently.config_filename)
      connection = Jenkins.new_connection("#{config[:jenkins_url]}/api/json", config, :use_json => true)

      response = connection.get do |req|
        req.params[:depth]  = 1
        req.params[:tree]   = 'assignedLabels[idleExecutors]'
        req.params[:random] = Time.now.to_i
      end
      response.body[:assignedLabels][0][:idleExecutors]
    rescue => e
      Log.log('Error when getting number of idle executors', e, :level => :error)
      sleep 5
      retry
    end
  end

  def new_job_id(pull_request_id)
    "#{pull_request_id}-#{(Time.now.to_f * 1000000).to_i}"
  end

  def start_job(pull_request_id)
    begin
      config     = ConfigFile.read(Jently.config_filename)
      connection = Jenkins.new_connection("#{config[:jenkins_url]}/job/#{config[:jenkins_job_name]}/buildWithParameters", config)

      job_id = new_job_id(pull_request_id)
      connection.post do |req|
        req.params[:id]         = job_id
        req.params[:branch]     = "origin/pr/#{pull_request_id}/merge"
        req.params[:repository] = config[:github_ssh_repository]
        req.params[:random]     = Time.now.to_i
      end
      job_id
    rescue => e
      Log.log('Error when starting job', e, :level => :error)
      sleep 5
      retry
    end
  end

  def wait_on_job(id)
    config = ConfigFile.read(Jently.config_filename)
    loop do
      state = get_job_state(id)
      return state if state
      interval = config[:jenkins_polling_interval_seconds]
      Log.log("Waiting on Jenkins job #{id} for #{interval} seconds", :level => :debug)
      sleep interval
    end
  end

  def get_job_state(job_id)
    begin
      config     = ConfigFile.read(Jently.config_filename)
      url        = "#{config[:jenkins_url]}/job/#{config[:jenkins_job_name]}/api/json"
      connection = Jenkins.new_connection(url, config, :use_json => true)

      begin
        response = connection.get do |req|
          req.params[:depth]  = 1
          req.params[:tree]   = 'builds[actions[parameters[name,value]],building,result,url]'
          req.params[:random] = Time.now.to_i
        end
      rescue Faraday::Error::ParsingError => e
        Log.log("There was a problem talking to Jenkins about the #{config[:jenkins_job_name]} job", :level => :error)
        Log.log('You may not have set up a parameterised Jenkins build per the README.', :level => :error)
        raise e
      end

      state = nil
      response.body[:builds].each do |build|
        begin
          if build[:actions][0][:parameters][2][:value] == job_id
            if !build[:building]
              state = {:status => 'success', :url => build[:url]} if build[:result] == 'SUCCESS'
              state = {:status => 'failure', :url => build[:url]} if build[:result] == 'UNSTABLE'
              state = {:status => 'failure', :url => build[:url]} if build[:result] == 'FAILURE'
            end
          end
        rescue
        end
      end
      state
    rescue => e
      Log.log('Error when getting job state', e, :level => :error)
      sleep 5
      retry
    end
  end

  def new_connection(url, config, opts = {})
    connection = Faraday.new(:url => url) do |c|
      c.use Faraday::Request::UrlEncoded
      c.use FaradayMiddleware::FollowRedirects
      c.use Faraday::Adapter::NetHttp
      if opts[:use_json]
        c.use FaradayMiddleware::Mashify
        c.use FaradayMiddleware::ParseJson
      end
    end

    if config.has_key?(:jenkins_login) && config.has_key?(:jenkins_password)
      connection.basic_auth(config[:jenkins_login], config[:jenkins_password])
    end
    connection
  end
end
