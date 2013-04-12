require 'spec_helper'

describe Logger do
  describe '.log' do
    let(:log_path) { File.join(Dir.pwd, 'rspec_log') }

    before do
      Logger.stub(:get_path).and_return(log_path)
      File.unlink(log_path) if File.exists?(log_path)
    end

    after do
      File.unlink(log_path) if File.exists?(log_path)
    end

    context 'when an exception is specified' do
      let(:exception_message) { 'something bad happened' }
      let(:exception_backtrace) { 'a valid backtrace' }

      let(:exception) { StandardError.new(exception_message) }

      it 'logs the exception message and backtrace' do
        exception.stub(:backtrace).and_return(exception_backtrace)
        Logger.log('anything', exception)
        results = File.read(log_path)
        results.should include exception_message
        results.should include exception_backtrace
      end
    end

    context 'when no exception is specified' do
      it 'logs just the specified log message' do
        message = "only this should appear"
        Logger.log(message)
        results = File.read(log_path)
        results.should match /.*#{message} \n\n\z/
      end
    end
  end
end
