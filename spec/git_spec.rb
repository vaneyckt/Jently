require 'spec_helper'

describe Git do
  let(:head_sha) { 'abc123' }
  let(:base_sha) { 'cde456' }
  let(:login) { 'rspec_github_login' }
  let(:password) { 'rspec_github_password' }
  let(:branch_name) { 'some_crazy_branch' }

  let(:repo_id) { "rspec_user/rspec_repo" }
  let(:repos_dir) { File.join('rspec_repositories') }
  let(:repo_path) { File.join(repos_dir, 'rspec_repo') }

  let(:pull_request) { { :head_sha => head_sha, :base_sha => base_sha } }
  let(:system_results) { [true, 'stdout', 'stderr'] }

  before do
    Repository.stub(:get_id).and_return(repo_id)
    Repository.stub(:get_path).and_return(repo_path)
    Repository.stub(:get_dir).and_return(repos_dir)

    Git.stub(:systemu).and_return(system_results)
    ConfigFile.stub(:read).and_return(:github_login => login, :github_password => password,
                                      :testing_branch_name => branch_name)
    Logger.stub(:log)
  end

  describe '.setup_testing_branch' do
    before do
      Repository.stub(:exists_locally).and_return(true)
      Git.stub(:delete_testing_branch)
      Git.stub(:create_testing_branch)
    end

    it 'does not clone the repository when it exists locally' do
      Repository.stub(:exists_locally).and_return(true)
      Git.should_not_receive(:clone_repository)

      Git.setup_testing_branch(pull_request)
    end

    it 'clones the repository when it does not exist locally' do
      Repository.stub(:exists_locally).and_return(false)
      Git.should_receive(:clone_repository)

      Git.setup_testing_branch(pull_request)
    end

    it 'deletes the existing testing branch' do
      Git.should_receive(:delete_testing_branch)

      Git.setup_testing_branch(pull_request)
    end

    it 'creates a new testing branch' do
      Git.should_receive(:create_testing_branch).with(pull_request)

      Git.setup_testing_branch(pull_request)
    end
  end

  describe '.delete_testing_branch' do
    it 'calls git commands that delete the testing branch' do
      Git.should_receive(:systemu).with(/\s*cd #{repo_path}.*git branch -D #{branch_name}.*git push origin :#{branch_name}/m).and_return(system_results)

      Git.delete_testing_branch
    end
  end

  describe '.create_testing_branch' do
    it 'checks out the head sha of the pull request' do
      Git.should_receive(:systemu).with(/\s*cd #{repo_path}.*git checkout #{head_sha}/m).and_return(system_results)

      Git.create_testing_branch(pull_request)
    end

    it 'creates a branch with the testing branch name' do
      Git.should_receive(:systemu).with(/git checkout -b #{branch_name}/m).and_return(system_results)

      Git.create_testing_branch(pull_request)
    end

    it 'merges the base branch up into the testing branch' do
      Git.should_receive(:systemu).with(/git merge #{base_sha}/m).and_return(system_results)

      Git.create_testing_branch(pull_request)
    end

    it 'pushes the merged branch up to the origin' do
      Git.should_receive(:systemu).with(/git push origin #{branch_name}/m).and_return(system_results)

      Git.create_testing_branch(pull_request)
    end
  end
end
