require 'spec_helper'

describe Repository do
  let(:github_username) { 'rspec_username' }
  let(:github_reponame) { 'rspec_reponame' }
  let(:repo_id) { "#{github_username}/#{github_reponame}" }
  let(:local_repos_dir) { File.join('rspec_repositories') }

  before do
    Repository.stub(:get_dir).and_return(local_repos_dir)
  end

  describe '.get_id' do
    it 'parses :github_ssh_repository config to get github org or username and the repo name' do
      ConfigFile.stub(:read).and_return( {:github_ssh_repository => "git@github.com:#{repo_id}.git"} )
      Repository.get_id.should eql repo_id
    end
  end

  describe '.get_name' do
    it 'parses the repo name from the repo id' do
      Repository.stub(:get_id).and_return(repo_id)
      Repository.get_name.should eql github_reponame
    end
  end

  describe '.get_path' do
    it 'returns the local repos dir joined with the github repo name' do
      Repository.stub(:get_id).and_return(repo_id)
      Repository.get_path.should eql "#{local_repos_dir}/#{github_reponame}"
    end
  end

  describe '.exists_locally' do
    before do
      Repository.stub(:get_id).and_return(repo_id)

      FileUtils.rmdir(Repository.get_path) if File.directory?(Repository.get_path)
      FileUtils.makedirs(local_repos_dir)
    end

    after do
      FileUtils.rmdir(Repository.get_path) if File.directory?(Repository.get_path)
      FileUtils.rmdir(local_repos_dir) if File.directory?(local_repos_dir)
    end

    it 'is true when the local repo dir exists' do
      FileUtils.makedirs( Repository.get_path )
      Repository.exists_locally.should be_true
    end

    it 'is false when the local repo dir does not exist' do
      Repository.exists_locally.should be_false
    end
  end

end
