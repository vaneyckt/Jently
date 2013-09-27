require 'bundler/setup'
require 'rspec/core/rake_task'
require 'colorize'

RSpec::Core::RakeTask.new('spec')

desc "build gem"
task :build do
  build_output = `gem build jently.gemspec`
  puts build_output

  gem_filename = build_output[/File: (.*)/,1]
  pkg_path = "pkg"
  FileUtils.mkdir_p(pkg_path)
  FileUtils.mv(gem_filename, pkg_path)

  puts "Gem built in #{pkg_path}/#{gem_filename}".green
end

desc "push gem"
task :push do
  filenames = Dir.glob("pkg/*.gem")
  filenames_with_times = filenames.map do |filename|
    [filename, File.mtime(filename)]
  end

  newest = filenames_with_times.sort_by { |tuple| tuple.last }.last
  newest_filename = newest.first

  command = "gem push #{newest_filename}"
  system(command)
end

task :default => [:spec]

