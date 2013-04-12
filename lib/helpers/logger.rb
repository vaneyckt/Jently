module Logger

  def Logger.get_path
    "#{Dir.pwd}/log"
  end

  def Logger.log(message, exception = nil)
    exception_output = " - #{exception} - #{exception.backtrace}" if exception
    File.open(get_path, 'a') { |file| file << log_prefix + message + exception_output.to_s + " \n\n" }
  end

  def self.log_prefix
    "#{Time.now} (#{Time.now.to_i})\n======================================\n"
  end

end
