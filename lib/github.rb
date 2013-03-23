require 'octokit'
require './lib/helpers.rb'

module Github
  def Github.get_open_pull_requests_ids
    begin
      config = ConfigFile.read
      repository_id = Repository.get_id
      client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])
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
      config = ConfigFile.read
      repository_id = Repository.get_id
      client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])
      pull_request = client.pull_request(repository_id, pull_request_id)
      statuses = client.statuses(repository_id, pull_request.head.sha)

      data = {}
      data[:id] = pull_request.number
      data[:merged] = pull_request.merged
      data[:mergeable] = pull_request.mergeable
      data[:head_branch] = pull_request.head.ref
      data[:base_branch_url] = pull_request.base.repo.ssh_url
      data[:base_branch] = pull_request.base.ref
      data[:head_branch_url] = pull_request.head.repo.ssh_url
      data[:head_sha] = pull_request.head.sha
      data[:status] = statuses.empty? ? 'undefined' : statuses.first.state

      # Update base_sha separately. The pull_request call is
      # not guarantueed to return the last sha of the base branch.
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
      config = ConfigFile.read
      repository_id = Repository.get_id
      head_sha = PullRequestsData.read[pull_request_id][:head_sha]

      opts = {}
      opts[:target_url] = state[:url] if !state[:url].nil?
      opts[:description] = state[:description] if !state[:description].nil?

      client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])
      client.create_status(repository_id, head_sha, state[:status], opts)
    rescue => e
      Logger.log('Error when setting pull request status', e)
      sleep 5
      retry
    end
  end
end