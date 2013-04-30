require 'systemu'

module Git
  def Git.clone_repository
    config = ConfigFile.read
    repository_id = Repository.get_id
    repository_dir = Repository.get_dir
    cmd = <<-GIT
      cd #{repository_dir} &&
      git clone https://#{config[:github_login]}:#{config[:github_password]}@github.com/#{repository_id}.git
    GIT
    Logger.log("Started cloning repository ...")
    status, stdout, stderr = systemu(cmd)
    Logger.log("Cloning repository - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end

  def Git.delete_local_testing_branch
    config = ConfigFile.read
    repository_path = Repository.get_path
    cmd = <<-GIT
      cd #{repository_path} &&
      git reset --hard &&
      git clean -df &&
      git checkout master &&
      git branch -D #{config[:testing_branch_name]} &&
    GIT
    status, stdout, stderr = systemu(cmd)
    Logger.log("Deleting local testing branch - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end

  def Git.delete_remote_testing_branch
    config = ConfigFile.read
    repository_path = Repository.get_path
    cmd = <<-GIT
      cd #{repository_path} &&
      git reset --hard &&
      git clean -df &&
      git checkout master &&
      git push origin :#{config[:testing_branch_name]}
    GIT
    status, stdout, stderr = systemu(cmd)
    Logger.log("Deleting remote testing branch - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end

  # Assume a pull request that wants to merge sha_A of branch_A into sha_B of branch_B.
  # The git commands can then be explained as:
  # - checkout sha_A. if sha_A is not the head of branch_A, then you'll end up in a headless state.
  # - make a new branch by branching of sha_A. This will give you a new branch irregardless of the state you were in before.
  # - merge sha_b into this newly created branch.
  # Your branch now contains the same code as would have been created by merging the pull request.
  # We can now run our tests on this branch in order to determine whether merging the pull request will break any tests.
  def Git.create_testing_branch(pull_request)
    config = ConfigFile.read
    repository_path = Repository.get_path
    cmd = <<-GIT
      cd #{repository_path} &&
      git reset --hard &&
      git clean -df &&
      git fetch --all &&
      git checkout #{pull_request[:head_sha]} &&
      git checkout -b #{config[:testing_branch_name]} &&
      git merge #{pull_request[:base_sha]} &&
      git push origin #{config[:testing_branch_name]}
    GIT
    status, stdout, stderr = systemu(cmd)
    Logger.log("Creating testing branch - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end

  def Git.setup_testing_branch(pull_request)
    Git.clone_repository if !Repository.exists_locally?
    Git.delete_local_testing_branch
    Git.delete_remote_testing_branch
    Git.create_testing_branch(pull_request)
  end
end
