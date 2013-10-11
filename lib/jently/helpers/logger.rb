require 'logger'
require 'time'
require 'socket'

module Log
  module_function
  def log(message, exception=nil, opts={})
    if exception.is_a?(Hash)
      opts      = exception
      exception = nil
    end

    options = {
      :level => exception ? :fatal : :info
    }.merge(opts)

    method = options[:level]
    if exception
      message << " :: #{exception} -\n#{exception.backtrace.join("\n")}".to_s
    end

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

    @logger.formatter = proc do |sev, datetime, progname, msg|
      hostname  = ::Socket.gethostname
      timestamp = datetime.iso8601
      severity  = sev.downcase
      "#{timestamp} #{hostname}: #{severity}: #{msg}\n"
    end
  end
end
