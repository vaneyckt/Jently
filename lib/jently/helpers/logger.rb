require 'logger'

module Log
  LOGGER = Logger.new(STDOUT)
  LOGGER.formatter = proc do |severity, datetime, progname, msg|
    header = "#{datetime} #{severity}:\n"
    header << '=' * header.strip.size
    header << "\n#{msg}\n"
  end

  module_function

  def log(message, exception=nil)
    exception_output = " - #{exception} -\n#{exception.backtrace.join("\n")}" if exception
    message += exception_output.to_s
    method = exception ? :fatal : :info
    LOGGER.send(method, message)
  end
end
