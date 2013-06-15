require 'systemu'

module Git
  def Git.clone_repository
    config = ConfigFile.read
    repository_id = Repository.get_id
    repository_dir = Repository.get_dir

    if(config.has_key?(:github_oauth_token))
       cmd = <<-GIT
         cd #{repository_dir} &&
         git clone #{config[:github_ssh_repository]}
       GIT
    else
       cmd = <<-GIT
         cd #{repository_dir} &&
         git clone https://#{config[:github_login]}:#{config[:github_password]}@github.com/#{repository_id}.git
       GIT
    end

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
      git fetch --all &&
      git checkout master &&
      git branch -D #{config[:testing_branch_name]}
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
      git fetch --all &&
      git checkout master &&
      git push origin :#{config[:testing_branch_name]}
    GIT

    status, stdout, stderr = systemu(cmd)
    Logger.log("Deleting remote testing branch - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end

  # Fetch the code that would result from merging this pull request straight from Github.
  # The branch containing this code will now be available locally as FETCH_HEAD.
  def Git.create_testing_branch(pull_request)
    config = ConfigFile.read
    repository_path = Repository.get_path

    cmd = <<-GIT
      cd #{repository_path} &&
      git reset --hard &&
      git clean -df &&
      git fetch origin refs/pull/#{pull_request[:id]}/merge &&
      git checkout FETCH_HEAD &&
      git checkout -b #{config[:testing_branch_name]} &&
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
