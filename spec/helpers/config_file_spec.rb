require 'spec_helper'

describe ConfigFile do
  describe '.read' do
    let(:config_path) { File.join('rspec_config.yaml') }

    before do
      ConfigFile.stub(:get_path).and_return(config_path)
      File.delete(config_path) if File.exists?(config_path)
    end

    after do
      File.delete(config_path) if File.exists?(config_path)
    end

    context 'when no config file exists' do
      it 'logs an error' do
        expected_error = "Config file unavailable -- no log file found in #{config_path}"
        Logger.should_receive(:log).with(expected_error)
        ConfigFile.read
      end
    end

    context 'when an empty config file exists' do
      it 'returns a hash with only a :whitelist_branches key that contains an empty set' do
        File.open(config_path, 'w'){|file| file.write( YAML.dump(nil) ) }
        ConfigFile.read.should eql Hash.new(:whitelist_branches => Set.new)
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

  describe 'whitelisted branches' do
    let(:config_path) { File.join('rspec_config.yaml') }
    let(:branch_1) { 'branch_1' }
    let(:branch_2) { 'branch_2' }

    before do
      ConfigFile.stub(:get_path).and_return(config_path)
      File.delete(config_path) if File.exists?(config_path)
    end

    after do
      File.delete(config_path) if File.exists?(config_path)
    end

    it 'returns an empty set if no :whitelist_branches key is defined' do
      File.open(config_path, 'w'){|file| file.write( "---\nfoo: baz\n" ) }

      ConfigFile.read[:whitelist_branches].should be_empty
    end

    it 'returns an empty set if :whitelist_branches value is an empty array' do
      File.open(config_path, 'w'){|file| file.write( "---\n:whitelist_branches:\n  -\n" ) }

      ConfigFile.read[:whitelist_branches].should be_empty
    end

    it 'returns a set containing a single specified whitelist branch' do
      File.open(config_path, 'w'){|file| file.write( "---\n:whitelist_branches:\n  - #{branch_1}\n" ) }

      ConfigFile.read[:whitelist_branches].should eql Set.new([branch_1])
    end

    it 'returns an array of multiple specified whitelist branches' do
      File.open(config_path, 'w'){|file| file.write( "---\n:whitelist_branches:\n  - #{branch_1}\n  - #{branch_2}\n" ) }

      ConfigFile.read[:whitelist_branches].should eql Set.new([branch_1, branch_2])
      ConfigFile.read[:whitelist_branches].should eql Set.new([branch_2, branch_1])
    end
  end
end
