require 'logger'

module Log
  class << self
    LOGGER = Logger.new(STDOUT)

    def log(message, exception=nil)
      exception_output = " - #{exception} -\n#{exception.backtrace.join("\n")}" if exception
      message += exception_output.to_s
      method = exception ? :fatal : :info
      LOGGER.send(method, message)
    end
  end

#  def Logger.log_prefix
#    "#{Time.now} (#{Time.now.to_i})\n======================================\n"
#  end
end
