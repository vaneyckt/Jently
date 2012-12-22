require 'daemons'

# http://daemons.rubyforge.org/classes/Daemons.html#M000005
pwd = Dir.pwd
Daemons.run_proc('jently') do
  Dir.chdir(pwd)
  exec "ruby jently.rb"
end
