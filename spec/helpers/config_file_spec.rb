require 'spec_helper'

describe ConfigFile do
  describe '.read' do
    let(:config_path) { File.join('rspec_config.yaml') }
    let(:stub_config) {
      {
        :github_login=>"github_login",
        :github_password=>"github_password",
        :github_ssh_repository=>"git@github.com:vaneyckt/Jently.git",
        :github_polling_interval_seconds=>60,
        :jenkins_login=>"jenkins_login",
        :jenkins_password=>"jenkins_password",
        :jenkins_url=>"jenkins_url",
        :jenkins_job_name=>"test_job",
        :jenkins_job_timeout_seconds=>1800,
        :jenkins_polling_interval_seconds=>60
      }
    }

    before do
      File.delete(config_path) if File.exists?(config_path)
    end

    after do
      File.delete(config_path) if File.exists?(config_path)
    end

    context 'when no config file exists' do
      it 'logs an error' do
        expected_error = "Config file unavailable -- no log file found in #{config_path}"
        Log.should_receive(:log).with(expected_error)
        ConfigFile.read(config_path)
      end
    end

    context 'when an empty config file exists' do
      it 'raises an exception' do
        File.open(config_path, 'w'){|file| file.write( YAML.dump(nil) ) }
        lambda {
          ConfigFile.read(config_path)
        }.should raise_error(NameError, /don't exist/)
      end
    end

    context 'when a config file exists' do
      let(:config_vars) { {:foo => 'bar'} }

      before do
        stub_config.merge!(config_vars)
        File.open(config_path, 'w'){|file| file << stub_config.to_yaml }
      end

      it 'returns the contents of the file, deserialized from YAML' do
        ConfigFile.read(config_path)[:foo].should eql 'bar'
      end

      it 'validates there are values for all config settings' do
        stub_config.merge!({:github_login => nil, :jenkins_password => ""})
        File.open(config_path, 'w'){|file| file << stub_config.to_yaml}

        lambda {
          ConfigFile.read(config_path)
        }.should raise_error(NameError, /aren't set/)

        lambda {
          ConfigFile.read(config_path)
        }.should raise_error(NameError, /github_login/)

        lambda {
          ConfigFile.read(config_path)
        }.should raise_error(NameError, /jenkins_password/)
      end
    end

    context 'when a config file exists containing ERB' do
      it 'returns the ERB-processed file, deserialized from YAML' do
        stub_config.merge!({:foo => "<%= 'baz' %>"})
        File.open(config_path, 'w'){ |file| file << stub_config.to_yaml }
        ConfigFile.read(config_path)[:foo].should eql 'baz'
      end
    end

    context 'when working with whitelisted branches' do
      let(:branch_1) { 'branch_1' }
      let(:branch_2) { 'branch_2' }

      it 'returns an empty set if no :whitelist_branches key is defined' do
        File.open(config_path, 'w'){ |file| file << stub_config.to_yaml }

        ConfigFile.read(config_path)[:whitelist_branches].should be_empty
      end

      it 'returns an empty set if :whitelist_branches value is an empty array' do
        stub_config.merge!(:whitelist_branches => [])
        File.open(config_path, 'w'){ |file| file << stub_config.to_yaml }

        ConfigFile.read(config_path)[:whitelist_branches].should be_empty
      end

      it 'returns a set containing a single specified whitelist branch' do
        stub_config.merge!(:whitelist_branches => [branch_1])
        File.open(config_path, 'w'){ |file| file << stub_config.to_yaml }

        ConfigFile.read(config_path)[:whitelist_branches].should eql Set.new([branch_1])
      end

      it 'returns an array of multiple specified whitelist branches' do
        stub_config.merge!(:whitelist_branches => [branch_1, branch_2])
        File.open(config_path, 'w'){ |file| file << stub_config.to_yaml }

        ConfigFile.read(config_path)[:whitelist_branches].should eql Set.new([branch_1, branch_2])
        ConfigFile.read(config_path)[:whitelist_branches].should eql Set.new([branch_2, branch_1])
      end
    end
  end
end
