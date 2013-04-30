require 'erb'
require 'yaml'

module ConfigFile
  def ConfigFile.get_path
    "#{Dir.pwd}/config/config.yaml.erb"
  end

  def ConfigFile.read
    path = get_path
    if File.exists?(path)
      raw_data = IO.read path
      erbified_data = ERB.new(raw_data).result
      YAML.load(erbified_data) || {}
    else
      Logger.log("Config file unavailable -- no log file found in #{get_path}")
    end
  end
end
