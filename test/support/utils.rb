# frozen_string_literal: true

require 'pty'
require 'expect'
require 'timeout'

module DEBUGGER__
  module TestUtils
    def type(command)
      @queue.push(command)
    end

    def assert_line_num(expected)
      @queue.push(Proc.new { |result|
        assert_equal(expected, result)
      })
    end

    def debug_code(program, &block)
      @queue = Queue.new
      block.call
      write_temp_file(program)
      create_psuedo_terminal
    end

    def take_number(sentence)
      sentence.match(/(.*):(.*)\r/)[2].to_i
    end

    def create_psuedo_terminal
      PTY.spawn("exe/rdbg #{temp_file_path}") do |read, write, pid|
        quit = false
        result = nil

        until quit
          read.expect(/(.*)\n|\(rdbg\)/) do |sentence|
            print sentence[0]
            if sentence[0] == '(rdbg)'
              cmd = @queue.pop
              if cmd.is_a?(Proc)
                cmd.call(result)
                cmd = @queue.pop
              end
              write.puts(cmd)
              quit = true if cmd == 'quit'
            elsif sentence[0].include?('=>#0')
              result = take_number(sentence[0])
            end
          end
        end
        read.expect(/.*\n/) do |sentence|
          print sentence[0]
        end
        read.expect(%r{(Really quit\? \[Y/n\])}) do |sentence|
          print sentence[0]
          write.puts('y')
        end
        read.expect(/.*\n/) do |sentence|
          print sentence[0]
        end
      end
    rescue NoMethodError
      p "terminal finished without reading 'y'"
      raise
    end
  end
end
