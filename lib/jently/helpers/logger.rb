require 'logger'

module Log
  module_function
  def log(message, exception=nil)
    exception_output = " - #{exception} -\n#{exception.backtrace.join("\n")}" if exception
    message += exception_output.to_s
    method = exception ? :fatal : :info

    logger.send(method, message)
  end

  def logger
    case
    when !@logger
      setup_logger
    when Jently.log_path != @logger.instance_variable_get("@logdev").filename
      setup_logger
    end

    @logger
  end

  def setup_logger
    if Jently && Jently.log_path
      @logger = Logger.new(Jently.log_path)
    else
      @logger = Logger.new(STDOUT)
    end

    @logger.formatter = proc do |severity, datetime, progname, msg|
      header = "#{datetime} #{severity}:\n"
      header << '=' * header.strip.size
      header << "\n#{msg}\n"
    end
  end
end
