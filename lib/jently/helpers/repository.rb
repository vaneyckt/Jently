module Repository
  def Repository.get_id
    config = ConfigFile.read(Jently.config_filename)
    config[:github_ssh_repository].split('.com:').last.split('.git').first
  end
end
