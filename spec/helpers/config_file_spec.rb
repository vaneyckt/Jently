require 'spec_helper'

describe ConfigFile do
  describe '.read' do
    let(:config_path) { File.join('rspec_config.yaml') }

    before do
      ConfigFile.stub(:get_path).and_return(config_path)
      File.unlink(config_path) if File.exists?(config_path)
    end

    after do
      File.unlink(config_path) if File.exists?(config_path)
    end

    context 'when no config file exists' do
      it 'logs an error' do
        expected_error = "Config file unavailable -- no log file found in #{config_path}"
        Logger.should_receive(:log).with(expected_error)
        ConfigFile.read
      end
    end

    context 'when an empty config file exists' do
      it 'returns an empty hash' do
        File.open(config_path, 'w'){|file| file.write( YAML.dump(nil) ) }
        ConfigFile.read.should eql Hash.new
      end
    end

    context 'when a config file exists' do
      let(:config_vars) { {'foo' => 'bar'} }

      before do
        File.open(config_path, 'w'){|file| file.write( YAML.dump(config_vars) ) }
      end

      it 'returns the contents of the file, deserialized from YAML' do
        ConfigFile.read['foo'].should eql 'bar'
      end
    end

    context 'when a config file exists containing ERB' do
      it 'returns the ERB-processed file, deserialized from YAML' do
        File.open(config_path, 'w'){|file| file.write( "---\nfoo: <%= 'baz' %>\n" ) }
        ConfigFile.read['foo'].should eql 'baz'
      end

    end
  end
end