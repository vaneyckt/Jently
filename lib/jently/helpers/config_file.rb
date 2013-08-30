require 'set'
require 'erb'
require 'yaml'

module ConfigFile
  module_function

  def read(path)
    if File.exists?(path)
      raw_data      = IO.read path
      erbified_data = ERB.new(raw_data).result
      config        = YAML.load(erbified_data) || {}

      # convert whitelist branches array to set to get rid of possible duplicates
      config[:whitelist_branches] = (!config.has_key?(:whitelist_branches)) ? Set.new : Set.new(config[:whitelist_branches].compact)

      validate(config)
      config
    else
      Log.log("Config file unavailable -- no log file found in #{path}")
    end
  end

  def validate(config)
    options = [
      :github_login,
      :github_password,
      :github_ssh_repository,
      :github_polling_interval_seconds,
      :jenkins_login,
      :jenkins_password,
      :jenkins_url,
      :jenkins_job_name,
      :jenkins_job_timeout_seconds,
      :jenkins_polling_interval_seconds,
    ]

    options.each do |option|
      raise NameError, "#{option} doesn't exist in config" if not config.include?(option)
      raise NameError, "#{option} isn't set in config" if not config[option]
    end
  end
end
