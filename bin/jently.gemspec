Gem::Specification.new do |s|
  s.name        = 'jently'
  s.version     = '1.0.3'
  s.date        = '2012-12-22'
  s.summary     = "A Ruby application that allows for communication between the Jenkins CI and Github."
  s.description = "A Ruby application that allows for communication between the Jenkins CI and Github."
  s.authors     = ["Tom Van Eyck"]
  s.email       = 'tomvaneyck@gmail.com'
  s.homepage    = 'https://github.com/vaneyckt/Jently'

  s.add_runtime_dependency 'systemu', '>= 2.5.2'
  s.add_runtime_dependency 'faraday', '>= 0.8.4'
  s.add_runtime_dependency 'octokit', '>= 1.13.0'
  s.add_runtime_dependency 'daemons', '>= 1.1.9'
end
