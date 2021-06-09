# frozen_string_literal: true

require 'pty'
require 'timeout'
require 'json'

module DEBUGGER__
  module TestUtils
    def type(command)
      @queue.push(command)
    end

    def assert_line_num(expected)
      @queue.push(Proc.new {
        assert_equal(expected, @internal_info['line'])
      })
    end

    def assert_line_text(expected)
      @queue.push(Proc.new {
        assert_match(expected, @internal_info['backlog'].join)
      })
    end

    def assert_fail_with_log msg, lines
      assert false,  "#{msg}\n" +
                     "[DEBUG SESSION LOG]\n" +
                     lines.map{|l| "> #{l}"}.join
    end

    def debug_code(program, **options, &block)
      @queue = Queue.new
      block.call
      write_temp_file(strip_line_num(program))
      create_pseudo_terminal(**options)
      check_line_num!(program)
    end

    DEBUG_MODE = false

    def debug_print msg
      print msg if DEBUG_MODE
    end

    RUBY = RbConfig.ruby

    def create_pseudo_terminal(boot_options: "-r debug/run")
      lib = "#{__dir__}/../../lib"

      ENV['RUBYOPT'] = "-I #{lib}"
      ENV['RUBY_DEBUG_USE_COLORIZE'] = "false"
      ENV['RUBY_DEBUG_TEST_MODE'] = 'true'

      timeout_sec = (ENV['RUBY_DEBUG_TIMEOUT_SEC'] || 10).to_i

      PTY.spawn("#{RUBY} #{boot_options} #{temp_file_path}") do |read, write, pid|
        @backlog = []
        @last_backlog = []
        begin
          Timeout.timeout(timeout_sec) do
            while (line = read.gets)
              debug_print line
              case line.chomp
              when '(rdbg)'
                cmd = @queue.pop
                if cmd.is_a?(Proc)
                  cmd.call
                  cmd = @queue.pop
                end
                write.puts(cmd)
                @last_backlog = []
              when /INTERNAL_INFO:\s(.*)/
                @internal_info = JSON.parse(Regexp.last_match(1))
                next # INTERNAL_INFO shouldn't be pushed into @backlog and @last_backlog
              when %r{Really quit\? \[Y/n\]}
                cmd = @queue.pop
                write.puts(cmd)
              end
              @backlog.push(line)
              @last_backlog.push(line)
            end
          end
        rescue Errno::EIO => e
          if @queue.empty?
            # result of `gets` return this exception in some platform
            # https://github.com/ruby/ruby/blob/master/ext/pty/pty.c#L729-L736
          else
            assert_fail_with_log e.message, lines
          end
        rescue Timeout::Error => e
          assert_fail_with_log "TIMEOUT ERROR (#{timeout_sec} sec)", lines
        end
      end
    end

    private

    LINE_NUMBER_REGEX = /^\s*\d+\| ?/

    def strip_line_num(str)
      str.gsub(LINE_NUMBER_REGEX, '')
    end

    def check_line_num!(program)
      unless program.match?(LINE_NUMBER_REGEX)
        new_program = program_with_line_numbers(program)
        raise "line numbers are required in test script. please update the script with:\n\n#{new_program}"
      end
    end

    def program_with_line_numbers(program)
      lines = program.split("\n")
      lines_with_number = lines.map.with_index do |line, i|
        "#{'%4d' % (i+1)}| #{line}"
      end

      lines_with_number.join("\n")
    end
  end
end
