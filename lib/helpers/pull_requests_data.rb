require 'yaml'

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

  def PullRequestsData.update(pull_request)
    data = read
    data[pull_request[:id]] = pull_request
    data[pull_request[:id]][:priority] = get_new_priority(pull_request)
    data[pull_request[:id]][:is_test_required] = is_test_required(pull_request)
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

  def PullRequestsData.reset(pull_request_id)
    data = read
    data[pull_request_id][:priority] = -1
    data[pull_request_id][:is_test_required] = false
    write(data)
  end

  def PullRequestsData.has_outdated_success_status(pull_request)
    data = read
    is_new = !data.has_key?(pull_request[:id])

    has_outdated_success_status = true
    has_outdated_success_status = has_outdated_success_status && !is_new
    has_outdated_success_status = has_outdated_success_status && pull_request[:status] == 'success'
    has_outdated_success_status = has_outdated_success_status && data[pull_request[:id]][:status] == 'success'
    has_outdated_success_status = has_outdated_success_status && data[pull_request[:id]][:base_sha] != pull_request[:base_sha]
  end

  def PullRequestsData.get_new_priority(pull_request)
    data = read
    is_new = !data.has_key?(pull_request[:id])
    priority = (is_new) ? 0 : (data[pull_request[:id]][:priority] + 1)
  end

  def PullRequestsData.is_test_required(pull_request)
    data = read
    is_new = !data.has_key?(pull_request[:id])
    is_merged = pull_request[:merged]

    is_waiting_to_be_tested = (is_new) ? false : data[pull_request[:id]][:is_test_required]
    has_inconsistent_status = (is_new) ? false : data[pull_request[:id]][:status] != pull_request[:status]

    has_invalid_status = false
    has_invalid_status = has_invalid_status || pull_request[:status] == 'error'
    has_invalid_status = has_invalid_status || pull_request[:status] == 'pending'
    has_invalid_status = has_invalid_status || pull_request[:status] == 'undefined'

    has_valid_status = false
    has_valid_status = has_valid_status || pull_request[:status] == 'success'
    has_valid_status = has_valid_status || pull_request[:status] == 'failure'

    was_updated = false
    was_updated = (is_new) ? false : (was_updated || data[pull_request[:id]][:head_sha] != pull_request[:head_sha])
    was_updated = (is_new) ? false : (was_updated || data[pull_request[:id]][:base_sha] != pull_request[:base_sha])

    is_test_required = !is_merged && (is_new || is_waiting_to_be_tested || has_inconsistent_status || has_invalid_status || (has_valid_status && was_updated))
  end

  def PullRequestsData.get_pull_request_id_to_test
    data = read
    pull_requests_that_require_testing = data.select { |pull_request_id, pull_request| pull_request[:is_test_required] }
    pull_request_id_to_test = (pull_requests_that_require_testing.empty?) ? nil : pull_requests_that_require_testing.max_by { |pull_request_id, pull_request| pull_request[:priority] }.first
  end
end
