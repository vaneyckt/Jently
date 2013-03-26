module Logger
  def Logger.get_path
    "#{Dir.pwd}/log"
  end

  def Logger.log(message, exception = nil)
    path = get_path
    File.open(path, 'a') { |f| f << "#{Time.now} (#{Time.now.to_i})\n======================================\n#{message} \n\n" } if exception.nil?
    File.open(path, 'a') { |f| f << "#{Time.now} (#{Time.now.to_i})\n======================================\n#{message} - #{exception} - #{exception.backtrace} \n\n" } if !exception.nil?
  end
end