require 'octokit'

module Github
  def Github.get_open_pull_requests_ids
    begin
      client = Github.new_client
      repository_id = Repository.get_id

      open_pull_requests = client.pull_requests(repository_id, 'open')
      open_pull_requests_ids = open_pull_requests.collect { |pull_request| pull_request.number }
    rescue => e
      Logger.log('Error when getting open pull requests ids', e)
      sleep 5
      retry
    end
  end

  def Github.get_pull_request(pull_request_id)
    begin
      client = Github.new_client
      repository_id = Repository.get_id

      pull_request = client.pull_request(repository_id, pull_request_id)
      statuses = client.statuses(repository_id, pull_request.head.sha)

      data = {}
      data[:id] = pull_request.number
      data[:merged] = pull_request.merged
      data[:mergeable] = pull_request.mergeable
      data[:head_branch] = pull_request.head.ref
      data[:head_sha] = pull_request.head.sha

      data[:status] = statuses.empty? ? 'undefined' : statuses.first.state

      # Update base_sha separately. The pull_request call is
      # not guaranteed to return the last sha of the base branch.
      data[:base_branch] = pull_request.base.ref
      data[:base_sha] = client.commits(repository_id, data[:base_branch]).first.sha
      data
    rescue => e
      Logger.log('Error when getting pull request', e)
      sleep 5
      retry
    end
  end

  def Github.set_pull_request_status(pull_request_id, state)
    begin
      repository_id = Repository.get_id
      head_sha = PullRequestsData.read[pull_request_id][:head_sha]

      opts = {}
      opts[:target_url] = state[:url] if !state[:url].nil?
      opts[:description] = state[:description] if !state[:description].nil?

      client = Github.new_client
      client.create_status(repository_id, head_sha, state[:status], opts)

      PullRequestsData.update_status(pull_request_id, state[:status])

      if state[:status] == 'success' || state[:status] == 'failure'
        PullRequestsData.reset(pull_request_id)
      end
    rescue => e
      Logger.log('Error when setting pull request status', e)
      sleep 5
      retry
    end
  end

  def new_client
    config = ConfigFile.read
    if config.has_key?(:github_api_endpoint)
      Octokit.configure do |c|
        c.api_endpoint = config[:github_api_endpoint]
        c.web_endpoint = config[:github_web_endpoint]
      end
    end

    if config.has_key?(:github_oauth_token)
      client = Octokit::Client.new(:login => config[:github_login], :oauth_token => config[:github_oauth_token])
    else
      client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])
    end
    client
  end
end
