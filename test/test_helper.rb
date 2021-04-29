$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'debug/version'
require_relative 'support/test_case'

DEBUGGER__::TestCase.before_suite
