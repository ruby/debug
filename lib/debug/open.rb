# frozen_string_literal: true
#
# Open the door for the debugger to connect.
# Users can connect to debuggee program with "rdbg --attach" option.
#
# If RUBY_DEBUG_PORT envval is provided (digits), open TCP/IP port.
# Otherwise, UNIX domain socket is used.
#
require "awesome_print"
require "pry"
require "zeitwerk"

module DEBUGGER__
  # Define these dummy constants so we silence errors like:
  #     expected file lib/debug/local.rb to define constant DEBUGGER__::Local, but didn't (Zeitwerk::NameError)
  module Local; end
  module Server; end
  module ServerCdp; end
  module ServerDap; end
  module Version; end

  # List special cases where constants are defined in files where they wouldn't otherwise be found
  autoload(:CONFIG, "#{__dir__}/config.rb")
  autoload(:SESSION, "#{__dir__}/config.rb")
  # autoload(:NaiveString, "#{__dir__}/server_dap.rb")
  autoload(:SkipPathHelper, "#{__dir__}/thread_client.rb")
  autoload(:UI_Base, "#{__dir__}/session.rb")
end

loader = Zeitwerk::Loader.new
loader.tag = File.basename(__FILE__, ".rb")
loader.inflector = Zeitwerk::GemInflector.new(__FILE__)
# loader.push_dir(__dir__)

loader.ignore(
  "lib/debug/start.rb",
  "lib/debug/open.rb",
  "lib/debug/open_nonstop.rb",
  "lib/debug/prelude.rb",
  "lib/debug/dap_custom/traceInspector.rb"
)

# Configure a special-case for this mangled module name
loader.push_dir(__dir__, namespace: DEBUGGER__)
# loader.inflector.inflect(
#   "debug" => "DEBUGGER__"
# )

loader.enable_reloading
loader.setup
loader.log!
puts "Zeitwerk configured!"

# ap({ roots: loader.send(:roots), ignored_paths: loader.send(:ignored_paths), all_paths: Zeitwerk::Loader.all_dirs })
# loader.eager_load
# puts("loaded constants under DEBUGGER__:")
# ap(DEBUGGER__.constants)
# exit(0)

require_relative 'session'
return unless defined?(DEBUGGER__)

DEBUGGER__.open
