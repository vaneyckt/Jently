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
      config
    else
      Log.log("Config file unavailable -- no log file found in #{path}")
    end
  end
end
