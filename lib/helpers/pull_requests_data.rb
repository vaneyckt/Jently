module PullRequestsData
  def PullRequestsData.get_path
    "#{Dir.pwd}/db/pull_requests.yaml"
  end

  def PullRequestsData.read
    path = get_path
    raw_data = IO.read path
    erbified_data = ERB.new(raw_data).result
    data = YAML.load(erbified_data) if File.exists?(path)
    data = !data ? {} : data
  end

  def PullRequestsData.write(data)
    path = get_path
    File.open(path, 'w') { |f| YAML.dump(data, f) }
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

  def PullRequestsData.find_pull_request_ids_with_success_status
    data = read
    data.delete_if { |pull_request_id, pull_request| pull_request[:status] != 'success' }
    data.keys
  end

  def PullRequestsData.is_success_status_outdated(pull_request)
    data = read
    is_outdated = (data[pull_request[:id]][:base_sha] != pull_request[:base_sha])
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
