# Start simplecov as a spawned process before debugger starts
require 'simplecov'
SimpleCov.command_name "spawn"
SimpleCov.at_fork.call(Process.pid)
SimpleCov.start

require "debug/session"
# Make sure simplecov is in the skip_path
simplecov_path = Gem.loaded_specs['simplecov'].full_require_paths.freeze + Gem.loaded_specs['simplecov-html'].full_require_paths.freeze
DEBUGGER__::CONFIG[:skip_path] = Array(DEBUGGER__::CONFIG[:skip_path]) + simplecov_path + RbConfig::CONFIG['rubylibprefix'].split(':')

# Start debugger similar to how it is started in exe/rdbg
DEBUGGER__.start no_sigint_hook: false, nonstop: true
DEBUGGER__::SESSION.add_line_breakpoint($0, 0, oneshot: true, hook_call: false)
