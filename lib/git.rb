require 'systemu'
require './lib/helpers.rb'

module Git
  def Git.clone_repository
    config = ConfigFile.read
    repository_id = Repository.get_id
    repository_dir = Repository.get_dir
    cmd = <<-GIT
      cd #{repository_dir} &&
      git clone https://#{config[:github_login]}:#{config[:github_password]}@github.com/#{repository_id}.git
    GIT
    puts 'Cloning repository ...'
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
      git checkout master &&
      git push origin :#{config[:testing_branch_name]}
    GIT
    status, stdout, stderr = systemu(cmd)
    Logger.log("Deleting remote testing branch - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end

  def Git.create_local_testing_branch(pull_request)
    config = ConfigFile.read
    repository_path = Repository.get_path
    cmd = <<-GIT
      cd #{repository_path} &&
      git reset --hard &&
      git clean -df &&
      git fetch --all &&
      git checkout #{pull_request[:head_sha]} &&
      git checkout -b #{config[:testing_branch_name]} &&
      git merge #{pull_request[:base_sha]}
    GIT
    status, stdout, stderr = systemu(cmd)
    Logger.log("Creating local testing branch - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end

  def Git.push_local_testing_branch_to_remote
    config = ConfigFile.read
    repository_path = Repository.get_path
    cmd = <<-GIT
      cd #{repository_path} &&
      git reset --hard &&
      git clean -df &&
      git checkout #{config[:testing_branch_name]} &&
      git push origin #{config[:testing_branch_name]}
    GIT
    status, stdout, stderr = systemu(cmd)
    Logger.log("Pushing local testing branch to remote - status: #{status} - stdout: #{stdout} - stderr: #{stderr}")
  end
end
