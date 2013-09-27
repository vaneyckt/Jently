#
# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "jently/version"

Gem::Specification.new do |s|
  s.name        = "jently"
  s.version     = Jently::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = [ "Tom Van Eyck" ]
  s.email       = [ "tomvaneyck@gmail.com" ]
  s.homepage    = "https://github.com/vaneyckt/Jently"
  s.summary     = "Trigger Jenkins builds on GitHub pull requests and update their commit status"
  s.description = "A Ruby app that makes your Jenkins CI automatically run tests on GitHub pull requests and updates their commit status."

  s.rubyforge_project = "jently"

  s.required_ruby_version     = ">= 1.8.7"
  s.required_rubygems_version = ">= 1.3.6"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'octokit',           '~> 1.24.0'
  s.add_runtime_dependency 'daemons',           '~> 1.1.9'
end
