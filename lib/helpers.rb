require 'yaml'

module Logger
  def Logger.get_path
    "#{Dir.pwd}/log"
  end

  def Logger.log(message)
    path = get_path
    File.open(path, 'a') { |f| f << "#{Time.now} (#{Time.now.to_i}) - #{message} \n" }
  end

  def Logger.log(message, exception)
    path = get_path
    File.open(path, 'a') { |f| f << "#{Time.now} (#{Time.now.to_i}) - #{message} - #{exception.backtrace} \n" }
  end
end

module ConfigFile
  def ConfigFile.get_path
    "#{Dir.pwd}/config/config.yaml"
  end

  def ConfigFile.read
    path = get_path
    data = YAML.load(File.read(path)) if File.exists?(path)
    data = !data ? {} : data
  end
end

module Repository
  def Repository.get_id
    config = ConfigFile.read
    config[:github_ssh_repository].split('github.com:').last.split('.git').first
  end

  def Repository.get_name
    get_id.split('/').last
  end

  def Repository.get_dir
    "#{Dir.pwd}/repositories"
  end

  def Repository.get_path
    repository_dir = get_dir
    repository_name = get_name
    "#{repository_dir}/#{repository_name}"
  end

  def Repository.exists_locally
    repository_path = get_path
    File.directory?(repository_path)
  end
end

module PullRequestsData
  def PullRequestsData.get_path
    "#{Dir.pwd}/db/pull_requests.yaml"
  end

  def PullRequestsData.read
    path = get_path
    data = YAML.load(File.read(path)) if File.exists?(path)
    data = !data ? {} : data
  end

  def PullRequestsData.write(pull_request)
    path = get_path
    File.open(path, 'w') { |f| YAML.dump(pull_request, f) }
  end

  def PullRequestsData.update(pull_request)
    data = read
    data[pull_request[:id]] = pull_request
    write(data)
  end

  def PullRequestsData.remove_dead_pull_requests(open_pull_requests_ids)
    data = read
    dead_pull_requests_ids = data.keys - open_pull_requests_ids
    dead_pull_requests_ids.each { |id| data.delete(id) }
    write(data)
  end

  def PullRequestsData.is_test_required(pull_request)
    data = read
    is_new = !data.has_key?(pull_request[:id])
    is_merged = pull_request[:merged]

    has_valid_status = false
    has_valid_status = has_valid_status or pull_request[:status] == 'success'
    has_valid_status = has_valid_status or pull_request[:status] == 'failure'

    has_invalid_status = false
    has_invalid_status = has_invalid_status or pull_request[:status] == 'error'
    has_invalid_status = has_invalid_status or pull_request[:status] == 'pending'
    has_invalid_status = has_invalid_status or pull_request[:status] == 'undefined'

    was_updated = false
    was_updated = (was_updated or data[pull_request[:id]][:head_sha] != pull_request[:head_sha]) if !is_new
    was_updated = (was_updated or data[pull_request[:id]][:base_sha] != pull_request[:base_sha]) if !is_new

    is_test_required = !is_merged and (is_new or has_invalid_status or (has_valid_status and was_updated))
  end
end
