require 'spec_helper'

describe Log do
  describe '.log' do
    let(:log_path) { File.join(Dir.pwd, 'rspec_log') }

    before do
      Jently.log_path = log_path
    end

    after do
      Jently.log_path
      #File.delete(log_path) if File.exists?(log_path)
    end

    context 'when an exception is specified' do
      let(:exception_message)   { 'something bad happened' }
      let(:exception_backtrace) { ['a valid backtrace'] }

      let(:exception) { StandardError.new(exception_message) }

      it 'logs the exception message and backtrace' do
        exception.stub(:backtrace).and_return(exception_backtrace)
        Log.log('anything', exception)

        results = File.read(log_path)
        results.should include exception_message
        results.should include exception_backtrace.join("\n")
      end
    end

    context 'when no exception is specified' do
      it 'logs just the specified log message' do
        message = "only this should appear"
        Log.log(message)
        results = File.read(log_path)

        results.should match /^#{message}\n\z/
      end
    end
  end
end
