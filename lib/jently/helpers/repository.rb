module Repository
  module_function
  def get_id
    config = ConfigFile.read(Jently.config_filename)

    repo = config[:github_ssh_repository]
    if repo =~ /^http/
      repo.split('/')[-2..-1].join('/').split('.git').first
    else
      repo.split('.com:').last.split('.git').first
    end
  end
end
