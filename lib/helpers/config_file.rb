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

  def ConfigFile.whitelist_branches
    branches = read[:whitelist_branches]

    # in case they've specified a single branch as a string, instead of an array
    branches = [branches] unless branches.is_a? Array
    Set.new(branches).delete(nil)
  end
end
