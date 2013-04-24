require 'spec_helper'

describe PullRequestsData do
  let(:datafile_path) { "#{Dir.pwd}/db/rspec_pull_requests.yaml" }

  before do
    PullRequestsData.stub(:get_path).and_return(datafile_path)
    File.delete(datafile_path) if File.exists?(datafile_path)
  end

  after do
    File.delete(datafile_path) if File.exists?(datafile_path)
  end

  describe '.read' do
    it 'returns an empty hash if no data file exists' do
      PullRequestsData.read.should eql Hash.new
    end

    context 'when an empty data file exists' do
      it 'returns an empty hash' do
        File.open(datafile_path, 'w'){|file| file.write( YAML.dump(nil) ) }
        PullRequestsData.read.should eql Hash.new
      end
    end

    context 'when a data file with data exists' do
      let(:data_hash) { {'foo' => 'bar'} }

      before do
        File.open(datafile_path, 'w'){|file| file.write( YAML.dump(data_hash) ) }
      end

      it 'returns the contents of the file, deserialized from YAML' do
        PullRequestsData.read['foo'].should eql 'bar'
      end
    end
  end


  describe '.write' do
    let(:data_hash) { {'a' => 'b'} }

    it 'creates a new data file if one does not exist' do
      File.delete(datafile_path) if File.exists?(datafile_path)

      PullRequestsData.write(data_hash)

      File.exists?(datafile_path).should be_true
    end

    it 'replaces an existing data file' do
      File.open(datafile_path, 'w'){ |file| file.write('abc') }

      PullRequestsData.write(data_hash)

      File.read(datafile_path).should_not eql 'abc'
    end

    it 'serializes data to be written into YAML' do
      PullRequestsData.write(data_hash)

      result = YAML.load(File.read(datafile_path))
      result['a'].should eql 'b'
    end
  end


  describe '.update' do
    let(:pull_request_id) { 'abc123' }
    let(:old_status) { 'success' }
    let(:new_status) { 'failed' }
    let(:old_priority) { 123 }
    let(:new_priority) { 456 }
    let(:old_test_required) { false }
    let(:new_test_required) { true }

    let(:old_data) { { :id => pull_request_id, :status => old_status, :priority => old_priority,
                       :is_test_required => old_test_required } }
    let(:new_data) { {:id => pull_request_id, :status => new_status} }

    before do
      PullRequestsData.stub(:get_new_priority).and_return(new_priority)
      PullRequestsData.stub(:test_required?).and_return(new_test_required)
      PullRequestsData.write( { pull_request_id => old_data} )
    end

    it 'replaces the current data for the specified pull request id with new data' do
      PullRequestsData.update( new_data )

      result = PullRequestsData.read
      result[pull_request_id][:status].should eql new_status
    end

    it 'finds and stores the new priority for the specified pull request' do
      PullRequestsData.should_receive(:get_new_priority).with( hash_including(new_data) ).
                        and_return(new_priority)

      PullRequestsData.update( new_data )

      result = PullRequestsData.read
      result[pull_request_id][:priority].should eql new_priority
    end

    it 'finds and stores whether a test is required for the specified pull request' do
      PullRequestsData.should_receive(:test_required?).with( hash_including(new_data) ).
                        and_return(new_test_required)

      PullRequestsData.update( new_data )

      result = PullRequestsData.read
      result[pull_request_id][:is_test_required].should eql new_test_required
    end
  end


  describe '.remove_dead_pull_requests' do
    it 'deletes pull requests that are not in the specified list of open pull request ids' do
      dead_pr_id = 123
      open_pr_id = 456
      open_pr = {:id => open_pr_id, :status => 'open'}
      PullRequestsData.write( { dead_pr_id => 'data', open_pr_id => open_pr} )

      PullRequestsData.remove_dead_pull_requests([open_pr_id])

      result = PullRequestsData.read
      result.should_not have_key dead_pr_id
      result[open_pr_id].should eql open_pr
    end
  end


  describe '.update_status' do
    it 'sets the status of the specified pr id to the specified status' do
      target_pr_id = 123
      other_pr_id  = 456
      target_pr = {:id => target_pr_id, :status => 'old'}
      other_pr  = {:id => other_pr_id,  :status => 'old'}
      PullRequestsData.write( { target_pr_id => target_pr, other_pr_id => other_pr} )

      PullRequestsData.update_status(target_pr_id, 'new')

      result = PullRequestsData.read
      result[target_pr_id][:status].should eql 'new'
      result[other_pr_id][:status].should eql 'old'
    end
  end


  describe '.reset' do
    it 'sets priority to -1 and test required to false for the specified pull request ' do
      target_pr_id = 123
      other_pr_id  = 456
      target_pr = {:id => target_pr_id, :priority => 0, :is_test_required => true}
      other_pr  = {:id => other_pr_id,  :priority => 0, :is_test_required => true}
      PullRequestsData.write( { target_pr_id => target_pr, other_pr_id => other_pr} )

      PullRequestsData.reset(target_pr_id)

      result = PullRequestsData.read
      result[target_pr_id][:priority].should eql -1
      result[target_pr_id][:is_test_required].should be_false

      result[other_pr_id][:priority].should eql 0
      result[other_pr_id][:is_test_required].should be_true
    end
  end


  describe '.outdated_success_status?' do
    let(:id) { 12345 }

    it 'is false if pull request is new' do
      PullRequestsData.outdated_success_status?({:id => id}).should be_false
    end

    let(:stored_sha) { 'abc123' }
    let(:stored_pr) { { :id => id, :status => 'success', :base_sha => stored_sha } }

    context 'when the pull request is not new' do
      before do
        PullRequestsData.write(id => stored_pr)
      end

      it 'is false if the specified pull request is not successful' do
        PullRequestsData.outdated_success_status?({:id => id, :status => 'failed'}).should be_false
      end

      it 'is false if the stored pull request is not successful' do
        PullRequestsData.write(id => stored_pr.merge(:status => 'failed'))
        PullRequestsData.outdated_success_status?(stored_pr).should be_false
      end

      it 'is false if the stored pull request sha is the same as the specified sha' do
        PullRequestsData.outdated_success_status?(stored_pr).should be_false
      end

      it 'is true if both the stored and specified pull requests are successful but have different shas' do
        PullRequestsData.outdated_success_status?(stored_pr.merge(:base_sha => 'other_sha')).should be_true
      end
    end
  end


  describe '.get_new_priority' do
    let(:id) { 456 }
    let(:old_priority) { 6 }
    let(:pr) { { :id => id, :priority => old_priority } }

    it 'returns 0 then the pull request is new' do
      PullRequestsData.get_new_priority(pr).should eql 0
    end

    it 'returns the current stored priority plus 1 when the pull request is not new' do
      PullRequestsData.write(id => pr)

      PullRequestsData.get_new_priority(pr).should eql (old_priority + 1)
    end
  end


  describe '.test_required?' do
    let(:id) { 789 }

    it 'is false if the pull request is merged' do
      PullRequestsData.test_required?({:id => id, :merged => true}).should be_false
    end

    context 'when the pull request is not merged' do
      it 'is true if the pull request is new' do
        PullRequestsData.test_required?({:id => id, :merged => false}).should be_true
      end

      context 'when the pr is not new' do
        it 'is true if the stored pull request is flagged as requiring testing' do
          PullRequestsData.write( id => {:id => id, :is_test_required => true} )

          PullRequestsData.test_required?({:id => id, :merged => false}).should be_true
        end

        it 'is true if the stored pr has a different status than the specified pr' do
          PullRequestsData.write( id => {:id => id, :status => 'one_thing'} )

          PullRequestsData.test_required?({:id => id, :merged => false, :status => 'other_thing'}).should be_true
        end

        it 'is true if the specified pr has an status of error' do
          PullRequestsData.write( id => {:id => id, :status => 'error'} )

          PullRequestsData.test_required?({:id => id, :merged => false, :status => 'error'}).should be_true
        end

        it 'is true if the specified pr has an status of pending' do
          PullRequestsData.write( id => {:id => id, :status => 'pending'} )

          PullRequestsData.test_required?({:id => id, :merged => false, :status => 'pending'}).should be_true
        end

        it 'is true if the specified pr has an status of undefined' do
          PullRequestsData.write( id => {:id => id, :status => 'undefined'} )

          PullRequestsData.test_required?({:id => id, :merged => false, :status => 'undefined'}).should be_true
        end

        context 'when the specified pr has a status of success' do
          let(:head_sha) { 'abc123' }
          let(:base_sha) { 'def456' }
          let(:stored_pr) { {:id => id, :merged => false, :status => 'success',
                             :head_sha => head_sha, :base_sha => base_sha } }

          before do
            PullRequestsData.write( id => stored_pr )
          end

          it 'is true if the stored pr and specified pr have different a head sha' do
            PullRequestsData.test_required?( stored_pr.merge(:head_sha => 'othersha') ).should be_true
          end

          it 'is true if the stored pr and specified pr have different a base sha' do
            PullRequestsData.test_required?( stored_pr.merge(:base_sha => 'othersha') ).should be_true
          end

          it 'is false if the stored pr and specified pr have the same head and base sha' do
            PullRequestsData.test_required?( stored_pr ).should be_false
          end
        end

        context 'when the specified pr has a status of failure' do
          let(:head_sha) { 'abc123' }
          let(:base_sha) { 'def456' }
          let(:stored_pr) { {:id => id, :merged => false, :status => 'failure',
                             :head_sha => head_sha, :base_sha => base_sha } }

          before do
            PullRequestsData.write( id => stored_pr )
          end

          it 'is true if the stored pr and specified pr have different a head sha' do
            PullRequestsData.test_required?( stored_pr.merge(:head_sha => 'othersha') ).should be_true
          end

          it 'is true if the stored pr and specified pr have different a base sha' do
            PullRequestsData.test_required?( stored_pr.merge(:base_sha => 'othersha') ).should be_true
          end

          it 'is false if the stored pr and specified pr have the same head and base sha' do
            PullRequestsData.test_required?( stored_pr ).should be_false
          end
        end
      end
    end
  end


  describe '.get_pull_request_id_to_test' do
    let(:not_required_id) { 123 }
    let(:not_required_pr) { { :id => not_required_id, :is_test_required => false } }

    it 'returns nil when there are no stored prs' do
      PullRequestsData.get_pull_request_id_to_test.should be_nil
    end

    it 'returns nil when there are no stored prs with is_test_required set to true' do
      PullRequestsData.write( not_required_id => not_required_pr )

      PullRequestsData.get_pull_request_id_to_test.should be_nil
    end

    let(:required_pr_1_id) { 456 }
    let(:required_pr_1) { { :id => required_pr_1_id, :is_test_required => true, :priority => 5 } }

    context 'when there are stored prs with is_test_required set to true and false' do
      it 'returns the only prs with is_test_required set to true' do
        PullRequestsData.write( not_required_id => not_required_pr, required_pr_1_id => required_pr_1 )

        PullRequestsData.get_pull_request_id_to_test.should eql required_pr_1_id
      end
    end

    context 'when there are multiple stored prs with is_test_required' do
      it 'returns the pr with the highest priority' do
        required_pr_2_id = 789
        required_pr_2 =  { :id => required_pr_2_id, :is_test_required => true, :priority => 6 }

        PullRequestsData.write( required_pr_1_id => required_pr_1, required_pr_2_id => required_pr_2 )

        PullRequestsData.get_pull_request_id_to_test.should eql required_pr_2_id

        PullRequestsData.write( required_pr_1_id => required_pr_1.merge(:priority => 7),
                                required_pr_2_id => required_pr_2 )

        PullRequestsData.get_pull_request_id_to_test.should eql required_pr_1_id
      end
    end
  end

end

