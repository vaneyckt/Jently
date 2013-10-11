require 'yaml'

module PullRequestsData
  module_function
  def path
    Jently.database_path
  end

  def read
    data = YAML.load(File.read(path)) if File.exists?(path)
    data || {}
  end

  def write(data)
    File.open(path, 'w') { |f| YAML.dump(data, f) }
  end

  def update(pull_request)
    data                                       = read
    data[pull_request[:id]]                    = pull_request
    data[pull_request[:id]][:priority]         = get_new_priority(pull_request)
    data[pull_request[:id]][:is_test_required] = test_required?(pull_request)
    write(data)
  end

  def remove_dead_pull_requests(open_pull_requests_ids)
    data                   = read
    dead_pull_requests_ids = data.keys - open_pull_requests_ids
    dead_pull_requests_ids.each { |id| data.delete(id) }
    write(data)
  end

  def update_status(pull_request_id, status)
    data                           = read
    data[pull_request_id][:status] = status
    write(data)
  end

  def reset(pull_request_id)
    data                                     = read
    data[pull_request_id][:priority]         = -1
    data[pull_request_id][:is_test_required] = false
    write(data)
  end

  def outdated_success_status?(pull_request)
    data   = read
    is_new = !data.has_key?(pull_request[:id])

    !is_new &&
    pull_request[:status] == 'success' &&
    data[pull_request[:id]][:status] == 'success' &&
    data[pull_request[:id]][:base_sha] != pull_request[:base_sha]
  end

  def get_new_priority(pull_request)
    data     = read
    is_new   = !data.has_key?(pull_request[:id])
    priority = (is_new) ? 0 : (data[pull_request[:id]][:priority] + 1)
  end

  def test_required?(pull_request)
    return false if pull_request[:merged]

    data   = read
    is_new = !data.has_key?(pull_request[:id])

    is_waiting_to_be_tested = (is_new) ? false : data[pull_request[:id]][:is_test_required]
    has_inconsistent_status = (is_new) ? false : data[pull_request[:id]][:status] != pull_request[:status]

    has_invalid_status = ['error', 'pending', 'undefined'].include?(pull_request[:status])
    has_valid_status   = ['success', 'failure'].include?(pull_request[:status])

    was_updated = (is_new) ? false : (data[pull_request[:id]][:head_sha] != pull_request[:head_sha]) ||
                                     (data[pull_request[:id]][:base_sha] != pull_request[:base_sha])

    is_test_required = is_new || is_waiting_to_be_tested || has_inconsistent_status || has_invalid_status || (has_valid_status && was_updated)
  end

  def next
    data   = read
    config = ConfigFile.read(Jently.config_filename)
    whitelist_branches = config[:whitelist_branches]

    to_test = data.values.select do |pr|
      pr[:is_test_required] && (whitelist_branches.empty? || whitelist_branches.include?(pr[:base_branch]))
    end
    to_test.empty? ? nil : to_test.max_by { |pull_request| pull_request[:priority] }[:id]
  end
end
