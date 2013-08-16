module Logger
  def Logger.get_path
    root = Pathname.new(__FILE__).parent.parent.parent
    (root + 'log').to_s
  end

  def Logger.log(message, exception = nil)
    exception_output = " - #{exception} - #{exception.backtrace}" if exception
    File.open(get_path, 'a') { |file| file << log_prefix + message + exception_output.to_s + " \n\n" }
  end

  def Logger.log_prefix
    "#{Time.now} (#{Time.now.to_i})\n======================================\n"
  end
end
