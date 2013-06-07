require 'octokit'

module GitHub_Client

  def GitHub_Client.get_client

    config = ConfigFile.read

    if(config.has_key?(:github_api_endpoint))

        Octokit.configure do |c|
            c.api_endpoint = config[:github_api_endpoint]
            c.web_endpoint = config[:github_web_endpoint]
        end

    end

    if(config.has_key?(:github_oauth_token))

       client = Octokit::Client.new(:login => config[:github_login], :oauth_token => config[:github_oauth_token])

    else

       client = Octokit::Client.new(:login => config[:github_login], :password => config[:github_password])

    end

    client

  end

end
