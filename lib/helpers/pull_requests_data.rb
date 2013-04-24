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
    stored_data = data_for(pull_request)
    stored_data && pull_request[:status] == 'success' &&
      stored_data[:status] == 'success' &&
      stored_data[:base_sha] != pull_request[:base_sha]
  end

  def PullRequestsData.get_new_priority(pull_request)
    stored_data = data_for(pull_request)
    (stored_data && stored_data[:priority] + 1) || 0
  end

  def self.data_for(pull_request)
    data = read
    data.has_key?(pull_request[:id]) && data[pull_request[:id]]
  end

  def PullRequestsData.test_required?(pull_request)
    return false if pull_request[:merged] # no need to load up and process stored data in this case

    stored_data = data_for(pull_request)

    is_waiting_to_be_tested = stored_data && stored_data[:is_test_required]
    has_inconsistent_status = stored_data && (stored_data[:status] != pull_request[:status])

    has_invalid_status = %w(error pending undefined).include? pull_request[:status]

    has_valid_status = %w(success failure).include? pull_request[:status]
    was_updated = stored_data && ( (stored_data[:head_sha] != pull_request[:head_sha]) ||
                                   (stored_data[:base_sha] != pull_request[:base_sha]) )

    !stored_data || is_waiting_to_be_tested || has_inconsistent_status || has_invalid_status ||
      (has_valid_status && was_updated )
  end

  def PullRequestsData.get_pull_request_id_to_test
    pull_requests_that_require_testing = read.values.select{ |pull_request| pull_request[:is_test_required] }
    highest_priority_pr = pull_requests_that_require_testing.max_by{ |pull_request| pull_request[:priority] }
    highest_priority_pr && highest_priority_pr[:id]
  end
end
