require 'yaml'

module PullRequestsData
  def PullRequestsData.get_path
    "#{Dir.pwd}/db/pull_requests.yaml"
  end

  def PullRequestsData.read
    path = get_path
    data = YAML.load(File.read(path)) if File.exists?(path)
    data || {}
  end

  def PullRequestsData.write(data)
    path = get_path
    File.open(path, 'w') { |f| YAML.dump(data, f) }
  end

  def PullRequestsData.update(pull_request)
    data = read
    data[pull_request[:id]] = pull_request
    data[pull_request[:id]][:priority] = get_new_priority(pull_request)
    data[pull_request[:id]][:is_test_required] = test_required?(pull_request)
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

  def PullRequestsData.outdated_success_status?(pull_request)
    data = read
    is_new = !data.has_key?(pull_request[:id])

    has_outdated_success_status = !is_new &&
                                  pull_request[:status] == 'success' &&
                                  data[pull_request[:id]][:status] == 'success' &&
                                  data[pull_request[:id]][:base_sha] != pull_request[:base_sha]
  end

  def PullRequestsData.get_new_priority(pull_request)
    data = read
    is_new = !data.has_key?(pull_request[:id])
    priority = (is_new) ? 0 : (data[pull_request[:id]][:priority] + 1)
  end

  def PullRequestsData.test_required?(pull_request)
    return false if pull_request[:merged]

    data = read
    is_new = !data.has_key?(pull_request[:id])

    is_waiting_to_be_tested = (is_new) ? false : data[pull_request[:id]][:is_test_required]
    has_inconsistent_status = (is_new) ? false : data[pull_request[:id]][:status] != pull_request[:status]

    has_invalid_status = ['error', 'pending', 'undefined'].include?(pull_request[:status])
    has_valid_status = ['success', 'failure'].include?(pull_request[:status])

    was_updated = (is_new) ? false : (data[pull_request[:id]][:head_sha] != pull_request[:head_sha]) ||
                                     (data[pull_request[:id]][:base_sha] != pull_request[:base_sha])

    is_test_required = is_new || is_waiting_to_be_tested || has_inconsistent_status || has_invalid_status || (has_valid_status && was_updated)
  end

  def PullRequestsData.get_pull_request_id_to_test
    data = read
    pull_requests_that_require_testing = data.values.select { |pull_request| pull_request[:is_test_required] }
    pull_request_id_to_test = (pull_requests_that_require_testing.empty?) ? nil : pull_requests_that_require_testing.max_by { |pull_request| pull_request[:priority] }[:id]
  end
end
