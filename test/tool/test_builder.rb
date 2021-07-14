# frozen_string_literal: true

require 'pty'
require 'expect'
require 'tempfile'
require 'json'

module DEBUGGER__
  class TestBuilder
    def initialize(target, m, c)
      @debuggee = File.absolute_path(target[0])
      m = "test_#{Time.now.to_i}" if m.nil?
      c = 'FooTest' if c.nil?
      @method = m
      @class = c.sub(/(^[a-z])/) { Regexp.last_match(1).upcase }
    end

    def start
      create_pseudo_terminal
      create_file
    end

    private

    def format_as_string
      return if @last_backlog[3]

      lines = "\n"
      @last_backlog[3].slice!("\e[?2004l\r")
      @last_backlog[3..].each{|l|
        # l.gsub!(/(')|(")/) doesn't work.
        l = l.gsub(/(\')/) { "\\#{Regexp.last_match(1)}" }
        l = l.gsub(/(\")/) { "\\#{Regexp.last_match(1)}" }
        lines += "\"#{l.chomp}\\r\\n\" \\\n"
      }
      lines
    end

    def format_as_regexp
      if index = @last_backlog.find_index('(rdbg)')
        index += 2
      else
        index = 0
      end
      len = @last_backlog.length - 1
      if len < index
        '//'
      elsif len == index
        Regexp.new(generate_pattern(@last_backlog[3])).inspect
      else
        lines = @last_backlog[index..].map{|l|
          l = generate_pattern(l)
          "          #{Regexp.new(l).inspect}"
        }.join(",\n")
        "[\n#{lines}\n        ]"
      end
    end

    def generate_pattern(line)
      line.slice!("\e[?2004l\r")
      file_name = File.basename(@debuggee, '.rb')
      escaped_line = Regexp.escape(line.chomp).gsub(/\\\s/, ' ')
      escaped_line.sub(%r{~.*#{file_name}.*|/Users/.*#{file_name}.*}, '.*')
    end

    RUBY = RbConfig.ruby

    def create_pseudo_terminal
      ENV['RUBYOPT'] = "-I #{__dir__}/../../lib"
      ENV['RUBY_DEBUG_NO_COLOR'] = 'true'
      ENV['RUBY_DEBUG_TEST_MODE'] = 'true'
      ENV['RUBY_DEBUG_TEST_ASSERT_AS_STRING'] ||= 'false'
      ENV['RUBY_DEBUG_TEST_ASSERT_AS_REGEXP'] ||= 'true'

      PTY.spawn("#{RUBY} -r debug/run #{@debuggee}") do |read, write, _|
        @backlog = []
        @last_backlog = []
        @scenario = []
        while (array = read.expect(%r{.*\n|\(rdbg\)|\[(?i)y/n\]}))
          line = array[0]
          print line
          case line.chomp
          when '(rdbg)'
            input = $stdin.gets
            input ||= 'quit'
            write.puts(input)
            command = input.chomp
          when %r{\[y/n\]}i
            input = $stdin.gets
            input ||= ''
            write.puts(input)
            @scenario.push("type '#{command}'")
            @scenario.push("type '#{input.chomp}'")
          when /INTERNAL_INFO:\s(.*)/
            if command && !@last_backlog.join.match?(/unknown command:/)
              @scenario.push("type '#{command}'")
              case command
              when 'step', 's', 'next', 'n', 'finish', 'fin', 'continue', 'c'
                @internal_info = JSON.parse(Regexp.last_match(1))
                @scenario.push("assert_line_num #{@internal_info['line']}")
              end
              @scenario.push("assert_line_text(#{format_as_string})") unless ENV['RUBY_DEBUG_TEST_ASSERT_AS_STRING'] == 'false'
              @scenario.push("assert_line_text(#{format_as_regexp})") unless ENV['RUBY_DEBUG_TEST_ASSERT_AS_REGEXP'] == 'false'
            end
            @last_backlog.clear
            next # INTERNAL_INFO shouldn't be pushed into @backlog and @last_backlog
          when /q!$/, /quit!$/
            @scenario.push("type '#{command}'")
          end

          @backlog.push(line)
          @last_backlog.push(line)
        end
      rescue Errno::EIO => e
        p e
      end
      exit if @backlog.empty? || @backlog[0].match?(/LoadError/)  # @debuggee is empty or doesn't exist
    end

    def format_scenario
      first_s = "#{@scenario[0]}\n"
      first_s + @scenario[1..].map{|s|
        "        #{s}"
      }.join("\n")
    end

    def content
      <<-TEST

    def #{@method}
      debug_code(program) do
        #{format_scenario}
      end
    end
      TEST
    end

    def format_program
      lines = File.read(@debuggee).split("\n")
      if lines.length > 9
        first_l = " 1| #{lines[0]}\n"
        indent_num = 9
        first_l + lines[1..].map.with_index{|l, i|
          if i < 9
            single_digit_line_num_temp(indent_num, i, l)
          else
            "#{' ' * (indent_num - 1)}#{i + 1}| #{l}"
          end
        }.join("\n")
      else
        first_l = "1| #{lines[0]}\n"
        indent_num = 8
        first_l + lines[1..].map.with_index{ |l, i| single_digit_line_num_temp(indent_num, i, l) }.join("\n")
      end
    end

    def single_digit_line_num_temp(indent_num, index, line)
      "#{' ' * indent_num}#{index + 1}| #{line}"
    end

    def content_with_module
      <<~TEST
        # frozen_string_literal: true

        require_relative '../support/test_case'

        module DEBUGGER__
          class #{@class} < TestCase
            def program
              <<~RUBY
                #{format_program}
              RUBY
            end
            #{content}  end
        end
      TEST
    end

    def create_file
      path = "#{__dir__}/../debug/#{@class.sub(/(?i:t)est/, '').downcase}_test.rb"
      if File.exist?(path)
        File.open(path, 'r') do |f|
          lines = f.read
          @content = lines.split("\n")[..-3].join("\n") + "\n#{content}  end\nend\n" if lines.include? @class
        end
      end
      if @content
        puts "appended: #{path}"
      else
        @content = content_with_module
        puts "created: #{path}"
        puts "    class: #{@class}"
      end
      puts "    method: #{@method}"

      File.write(path, @content)
    end

    def remove_temp_file
      File.unlink(@temp_file)
      @temp_file = nil
    end
  end
end
