require "bundler/gem_tasks"
require "rake/testtask"

begin
  require "rake/extensiontask"
  task :build => :compile

  Rake::ExtensionTask.new("debug") do |ext|
    ext.lib_dir = "lib/debug"
  end
rescue LoadError
end

task :default => [:clobber, :compile, 'README.md', :check_readme, :test_console]

file 'README.md' => ['lib/debug/session.rb', 'lib/debug/config.rb',
                     'exe/rdbg', 'misc/README.md.erb'] do
  require_relative 'lib/debug/session'
  require 'erb'
  File.write 'README.md', ERB.new(File.read('misc/README.md.erb')).result
  puts 'README.md is updated.'
end

task :check_readme do
  require_relative 'lib/debug/session'
  require 'erb'
  current_readme = File.read("README.md")
  generated_readme = ERB.new(File.read('misc/README.md.erb')).result

  if current_readme != generated_readme
    fail <<~MSG
      The content of README.md doesn't match its template and/or source.
      Please apply the changes to info source (e.g. command comments) or the template and run 'rake README.md' to update README.md.
    MSG
  end
end

desc "Run all debugger console related tests"
Rake::TestTask.new(:test_console) do |t|
  t.test_files = FileList["test/console/*_test.rb", "test/*_test.rb"]
end

desc "Run all debugger protocols (CAP & DAP) related tests"
Rake::TestTask.new(:test_protocol) do |t|
  t.test_files = FileList["test/protocol/*_test.rb"]
end

task :test do
  fail <<~MSG
    `rake test` isn't supported yet because protocol tests are still unstable.
    To run all test cases, please use `rake test_all` instead.
  MSG
end

task test_all: [:test_console, :test_protocol]
