Gem::Specification.new do |s|
  s.name        = 'jently'
  s.version     = '1.0.0'
  s.date        = '2012-09-10'
  s.summary     = "A Ruby application that allows for communication between the Jenkins CI and Github."
  s.description = "A Ruby application that allows for communication between the Jenkins CI and Github."
  s.authors     = ["Tom Van Eyck"]
  s.email       = 'tomvaneyck@gmail.com'
  s.homepage    = 'https://github.com/vaneyckt/Jently'

  s.add_runtime_dependency 'faraday'
  s.add_runtime_dependency 'octokit'
end
