module ConfigFile
  def ConfigFile.get_path
    "#{Dir.pwd}/config/config.yaml"
  end

  def ConfigFile.read
    path = get_path
    if File.exist?(path)
      raw_data = IO.read path
      erbified_data = ERB.new(raw_data).result
      data = YAML.load(erbified_data) if File.exists?(path)
      data = !data ? {} : data
    else
      Logger.log("Config file unavailable -- no log file found in #{ConfigFile.get_path}")
    end
  end
end