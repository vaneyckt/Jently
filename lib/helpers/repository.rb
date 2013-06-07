module Repository
  def Repository.get_id
    config = ConfigFile.read
    config[:github_ssh_repository].split('com:').last.split('.git').first
  end

  def Repository.get_name
    get_id.split('/').last
  end

  def Repository.get_dir
    "#{Dir.pwd}/repositories"
  end

  def Repository.get_path
    repository_dir = get_dir
    repository_name = get_name
    "#{repository_dir}/#{repository_name}"
  end

  def Repository.exists_locally?
    repository_path = get_path
    File.directory?(repository_path)
  end
end
