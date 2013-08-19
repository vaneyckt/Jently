require 'spec_helper'

describe Git do
  let(:id)          { '123' }
  let(:head_sha)    { 'abc123' }
  let(:base_sha)    { 'cde456' }
  let(:login)       { 'rspec_github_login' }
  let(:password)    { 'rspec_github_password' }
  let(:oauth_token) { 'rspec_github_oauth_token' }
  let(:branch_name) { 'some_crazy_branch' }

  let(:repo_id)   { "rspec_user/rspec_repo" }
  let(:repos_dir) { File.join('rspec_repositories') }
  let(:repo_path) { File.join(repos_dir, 'rspec_repo') }

  let(:merge_ref) { "refs/pull/#{id}/merge" }

  let(:pull_request)   { { :id => id, :head_sha => head_sha, :base_sha => base_sha } }
  let(:system_results) { [true, 'stdout', 'stderr'] }

  before do
    Repository.stub(:get_id).and_return(repo_id)
    Repository.stub(:get_path).and_return(repo_path)
    Repository.stub(:get_dir).and_return(repos_dir)

    Git.stub(:systemu).and_return(system_results)
    ConfigFile.stub(:read).and_return(:github_login => login, :github_password => password, :testing_branch_name => branch_name)
    Logger.stub(:log)
  end

  describe '.setup_testing_branch' do
    before do
      Repository.stub(:exists_locally?).and_return(true)
      Git.stub(:delete_local_testing_branch)
      Git.stub(:delete_remote_testing_branch)
      Git.stub(:create_testing_branch)
    end

    context 'when the github authentication is performed with a login and password' do
      it 'does not clone the repository when it exists locally' do
        Repository.stub(:exists_locally?).and_return(true)
        Git.should_not_receive(:clone_repository)

        Git.setup_testing_branch(pull_request)
      end

      it 'clones the repository when it does not exist locally' do
        Repository.stub(:exists_locally?).and_return(false)
        Git.should_receive(:clone_repository)

        Git.setup_testing_branch(pull_request)
      end
    end

    context 'when the github authentication is performed with a login and oauth token' do
      before do
        ConfigFile.stub(:read).and_return(:github_login => login, :github_oauth_token => oauth_token,
                                          :testing_branch_name => branch_name)
      end

      it 'does not clone the repository when it exists locally' do
        Repository.stub(:exists_locally?).and_return(true)
        Git.should_not_receive(:clone_repository)

        Git.setup_testing_branch(pull_request)
      end

      it 'clones the repository when it does not exist locally' do
        Repository.stub(:exists_locally?).and_return(false)
        Git.should_receive(:clone_repository)

        Git.setup_testing_branch(pull_request)
      end
    end

    it 'deletes the existing testing branch' do
      Git.should_receive(:delete_local_testing_branch)
      Git.should_receive(:delete_remote_testing_branch)

      Git.setup_testing_branch(pull_request)
    end

    it 'creates a new testing branch' do
      Git.should_receive(:create_testing_branch).with(pull_request)

      Git.setup_testing_branch(pull_request)
    end
  end

  describe '.delete_local testing_branch' do
    it 'calls git commands that delete the local testing branch' do
      Git.should_receive(:systemu).with(/\s*cd #{repo_path}.*git branch -D #{branch_name}/m).and_return(system_results)

      Git.delete_local_testing_branch
    end
  end

  describe '.delete_remote testing_branch' do
    it 'calls git commands that delete the remote testing branch' do
      Git.should_receive(:systemu).with(/\s*cd #{repo_path}.*git push origin :#{branch_name}/m).and_return(system_results)

      Git.delete_remote_testing_branch
    end
  end

  describe '.create_testing_branch' do
    it 'creates a branch with the testing branch name' do
      Git.should_receive(:systemu).with(/git checkout -b #{branch_name}/m).and_return(system_results)

      Git.create_testing_branch(pull_request)
    end

    it 'fetches the merged reference of the pull request' do
      Git.should_receive(:systemu).with(/git fetch origin #{merge_ref}/m).and_return(system_results)

      Git.create_testing_branch(pull_request)
    end

    it 'pushes the merged branch up to the origin' do
      Git.should_receive(:systemu).with(/git push origin #{branch_name}/m).and_return(system_results)

      Git.create_testing_branch(pull_request)
    end
  end
end
