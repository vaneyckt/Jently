require 'yaml'

module Logger
  def Logger.get_path
    "#{Dir.pwd}/log"
  end

  def Logger.log(message, exception = nil)
    path = get_path
    File.open(path, 'a') { |f| f << "#{Time.now} (#{Time.now.to_i})\n======================================\n#{message} \n\n" } if exception.nil?
    File.open(path, 'a') { |f| f << "#{Time.now} (#{Time.now.to_i})\n======================================\n#{message} - #{exception} - #{exception.backtrace} \n\n" } if !exception.nil?
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

  def PullRequestsData.write(data)
    path = get_path
    File.open(path, 'w') { |f| YAML.dump(data, f) }
  end

  def PullRequestsData.update(pull_request, opts = {:priority => 0, :is_test_required => false})
    data = read
    data[pull_request[:id]] = pull_request.merge(opts)
    write(data)
  end

  def PullRequestsData.remove_dead_pull_requests(open_pull_requests_ids)
    data = read
    dead_pull_requests_ids = data.keys - open_pull_requests_ids
    dead_pull_requests_ids.each { |id| data.delete(id) }
    write(data)
  end

  def PullRequestsData.update_status(pull_request_id, status)
    data = read
    data[pull_request_id][:status] = status
    write(data)
  end

  def PullRequestsData.is_success_status_outdated(pull_request)
    data = read
    is_new = !data.has_key?(pull_request[:id])

    is_outdated = true
    is_outdated = is_outdated && !is_new
    is_outdated = is_outdated && pull_request[:status] == 'success'
    is_outdated = is_outdated && data[pull_request[:id]][:status] == 'success'
    is_outdated = is_outdated && data[pull_request[:id]][:base_sha] != pull_request[:base_sha]
  end

  def PullRequestsData.get_pull_request_id_to_test
    data = read
    pull_requests_that_require_testing = data.select { |pull_request_id, pull_request| pull_request[:is_test_required] }
    pull_request_id_to_test = (pull_requests_that_require_testing.empty?) ? nil : pull_requests_that_require_testing.max_by { |pull_request_id, pull_request| pull_request[:priority] }.first
  end

  def PullRequestsData.get_priority(pull_request)
    data = read
    is_new = !data.has_key?(pull_request[:id])
    priority = (is_new) ? 0 : (data[pull_request[:id]][:priority] + 1)
  end

  def PullRequestsData.is_test_required(pull_request)
    data = read
    is_new = !data.has_key?(pull_request[:id])
    is_merged = pull_request[:merged]

    has_valid_status = false
    has_valid_status = has_valid_status || pull_request[:status] == 'success'
    has_valid_status = has_valid_status || pull_request[:status] == 'failure'

    has_invalid_status = false
    has_invalid_status = has_invalid_status || pull_request[:status] == 'error'
    has_invalid_status = has_invalid_status || pull_request[:status] == 'pending'
    has_invalid_status = has_invalid_status || pull_request[:status] == 'undefined'

    was_updated = false
    was_updated = (was_updated || data[pull_request[:id]][:head_sha] != pull_request[:head_sha]) if !is_new
    was_updated = (was_updated || data[pull_request[:id]][:base_sha] != pull_request[:base_sha]) if !is_new

    is_test_required = !is_merged && (is_new || has_invalid_status || (has_valid_status && was_updated))
  end
end
