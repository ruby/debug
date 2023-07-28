# frozen_string_literal: true
#
# Open the door for the debugger to connect.
# Users can connect to debuggee program with "rdbg --attach" option.
#
# If RUBY_DEBUG_PORT envval is provided (digits), open TCP/IP port.
# Otherwise, UNIX domain socket is used.
#

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore(
  "lib/debug/start.rb",
  "lib/debug/open.rb",
  "lib/debug/open_nonstop.rb",
  "lib/debug/prelude.rb",
  "lib/debug/dap_custom/traceInspector.rb"
)
loader.enable_reloading
loader.setup
loader.log!
puts "Zeitwerk configured!"

require_relative 'session'
return unless defined?(DEBUGGER__)

DEBUGGER__.open
