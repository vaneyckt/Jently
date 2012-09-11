require 'faraday'
require './lib/helpers.rb'

module Jenkins
  def Jenkins.wait_for_idle_executor
    config = ConfigFile.read
    while true
      return if Jenkins.get_nb_of_idle_executors >= 1
      sleep config[:jenkins_polling_interval_seconds]
    end
  end

  def Jenkins.get_nb_of_idle_executors
    begin
      config = ConfigFile.read
      connection = Faraday.new(:url => "#{config[:jenkins_url]}/api/json") do |c|
        c.use Faraday::Request::UrlEncoded
        c.use FaradayMiddleware::FollowRedirects
        c.use FaradayMiddleware::Mashify
        c.use FaradayMiddleware::ParseJson
        c.use Faraday::Adapter::NetHttp
      end

      if config.has_key?(:jenkins_login) and config.has_key?(:jenkins_password)
        connection.basic_auth config[:jenkins_login], config[:jenkins_password]
      end

      response = connection.get do |req|
        req.params[:depth] = 1
        req.params[:tree] = 'assignedLabels[idleExecutors]'
      end
      response.body[:assignedLabels][0][:idleExecutors]
    rescue => e
      sleep 5
      retry
    end
  end

  def Jenkins.start_jo
    begin
      config = ConfigFile.read
      connection = Faraday.new(:url => "#{config[:jenkins_url]}/job/#{config[:jenkins_job_name]}/buildWithParameters") do |c|
        c.use Faraday::Request::UrlEncoded
        c.use FaradayMiddleware::FollowRedirects
        c.use Faraday::Adapter::NetHttp
      end

      if config.has_key?(:jenkins_login) and config.has_key?(:jenkins_password)
        connection.basic_auth config[:jenkins_login], config[:jenkins_password]
      end

      job_id = (Time.now.to_f * 1000000).to_i.to_s
      connection.get do |req|
        req.params[:id] = job_id
        req.params[:branch] = config[:testing_branch_name]
        req.params[:repository] = config[:github_ssh_repository]
      end
      job_id
    rescue => e
      sleep 5
      retry
    end
  end

  def Jenkins.wait_on_job(job_id)
    config = ConfigFile.read
    while true
      state = Jenkins.get_job_state(job_id)
      return state if !state.nil?
      sleep config[:jenkins_polling_interval_seconds]
    end
  end

  def Jenkins.get_job_state(job_id)
    begin
      config = ConfigFile.read
      connection = Faraday.new(:url => "#{config[:jenkins_url]}/job/#{config[:jenkins_job_name]}/api/json") do |c|
        c.use Faraday::Request::UrlEncoded
        c.use FaradayMiddleware::FollowRedirects
        c.use FaradayMiddleware::Mashify
        c.use FaradayMiddleware::ParseJson
        c.use Faraday::Adapter::NetHttp
      end

      if config.has_key?(:jenkins_login) and config.has_key?(:jenkins_password)
        connection.basic_auth config[:jenkins_login], config[:jenkins_password]
      end

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
      sleep 5
      retry
    end
  end
end
