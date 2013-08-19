require 'spec_helper'

describe Repository do
  let(:github_username) { 'rspec_username' }
  let(:github_reponame) { 'rspec_reponame' }
  let(:repo_id)         { "#{github_username}/#{github_reponame}" }
  let(:local_repos_dir) { File.join('rspec_repositories') }

  describe '.get_id' do
    it 'parses :github_ssh_repository config to get github org or username and the repo name' do
      ConfigFile.stub(:read).and_return( {:github_ssh_repository => "git@github.com:#{repo_id}.git"} )
      Repository.get_id.should eql repo_id
    end
  end
end
