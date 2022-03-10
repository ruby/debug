require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.test_files = FileList["test/**/*_test.rb"]
end

begin
  require "rake/extensiontask"
  task :build => :compile

  Rake::ExtensionTask.new("debug") do |ext|
    ext.lib_dir = "lib/debug"
  end
rescue LoadError
end

task :default => [:clobber, :compile, 'README.md', :test]

file 'README.md' => ['lib/debug/session.rb', 'lib/debug/config.rb',
                     'exe/rdbg', 'misc/README.md.erb'] do
  require_relative 'lib/debug/session'
  require 'erb'
  File.write 'README.md', ERB.new(File.read('misc/README.md.erb')).result
  puts 'README.md is updated.'
end

task :test_protocol do
  ENV['RUBY_DEBUG_PROTOCOL_TEST'] = '1'
end

Rake::TestTask.new(:test_protocol) do |t|
  t.test_files = FileList["test/protocol/*_test.rb"]
end
