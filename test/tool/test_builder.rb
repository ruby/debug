# frozen_string_literal: true

require 'pty'
require 'expect'
require 'json'
require 'open3'

module DEBUGGER__
  class TestBuilderBase
    # TODO: Refactor the logic when creating the test generator for CDP.
  end

  class LocalTestBuilder < TestBuilderBase
    def initialize(target, m, c)
      @target_path = File.absolute_path(target[0])
      @current_time = Time.now.to_i
      m = "test_#{@current_time}" if m.nil?
      @method = m
      c = 'FooTest' if c.nil?
      c_upcase = c.sub(/(^[a-z])/) { Regexp.last_match(1).upcase }
      if c_upcase.match? /(?i:t)est/
        @class = c_upcase
      else
        @class = "#{c_upcase}Test"
      end
    end

    def start
      activate_debugger
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
      if index = @last_backlog.index { |l| l.match? /\(rdbg\)/ }
        index += 2
      else
        index = 0
      end
      len = @last_backlog.length - 1
      if len < index
        '//'
      elsif len == index
        Regexp.new(generate_pattern(@last_backlog[index])).inspect
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
      file_name = File.basename(@target_path, '.rb')
      escaped_line = Regexp.escape(line.chomp).gsub(/\\\s/, ' ')
      escaped_line.sub(%r{~.*#{file_name}.*|/Users/.*#{file_name}.*}, '.*')
    end

    RUBY = ENV['RUBY'] || RbConfig.ruby

    def activate_debugger
      ENV['RUBYOPT'] = "-I #{__dir__}/../../lib"
      ENV['RUBY_DEBUG_NO_COLOR'] = 'true'
      ENV['RUBY_DEBUG_TEST_UI'] = 'terminal'
      ENV['RUBY_DEBUG_TEST_ASSERT_AS_STRING'] ||= 'false'
      ENV['RUBY_DEBUG_TEST_ASSERT_AS_REGEXP'] ||= 'true'
      ENV['RUBY_DEBUG_NO_RELINE'] = 'true'

      PTY.spawn("#{RUBY} -r debug/start #{@target_path}") do |read, write, _|
        @backlog = []
        @last_backlog = []
        @scenario = []
        while (array = read.expect(%r{.*\n|\(rdbg\)|\[(?i)y/n\]}))
          line = array[0]
          print line
          @backlog.push(line)
          @last_backlog.push(line)
          case line.chomp
          when /\(rdbg\)/
            command = write_user_input(write, 'quit')
          when %r{\[y/n\]}i
            @scenario.push("type '#{command}'")
            @scenario.push("assert_line_text(#{format_as_string})") unless ENV['RUBY_DEBUG_TEST_ASSERT_AS_STRING'] == 'false'
            @scenario.push("assert_line_text(#{format_as_regexp})") unless ENV['RUBY_DEBUG_TEST_ASSERT_AS_REGEXP'] == 'false'
            @scenario.push("type '#{write_user_input(write, '')}'")
            command = nil
            @last_backlog.clear
          when /INTERNAL_INFO:\s(.*)/
            # INTERNAL_INFO shouldn't be pushed into @backlog and @last_backlog
            @backlog.pop
            @last_backlog.pop

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
          when /q!$/, /quit!$/
            @scenario.push("type '#{command}'")
          end
        end
      rescue Errno::EIO => e
        p e
      end
      exit if @backlog.empty? || @backlog[0].match?(/LoadError/)  # @target_path is empty or doesn't exist
    end

    def write_user_input(write, default)
      input = $stdin.gets
      input ||= default
      write.puts(input)
      input.chomp
    end

    def format_scenario
      first_s = "#{@scenario[0]}\n"
      first_s + @scenario[1..].map{|s|
        "        #{s}"
      }.join("\n")
    end

    def create_scenario
      <<-TEST.chomp

    def #{@method}
      debug_code(program) do
        #{format_scenario}
      end
    end
      TEST
    end

    def create_scenario_and_program
      <<-TEST.chomp

  class #{@class}#{@current_time} < TestCase
    def program
      <<~RUBY
        #{format_program}
      RUBY
    end
    #{create_scenario}
  end
      TEST
    end

    def format_program
      src = @target_src || File.read(@target_path)
      lines = src.split("\n")
      indent_num = 8
      if lines.length > 9
        first_l = " 1| #{lines[0]}\n"
        first_l + lines[1..].map.with_index{|l, i|
          if i < 8
            line_num_temp(indent_num + 1, i, l)
          else
            line_num_temp(indent_num, i, l)
          end
        }.join("\n")
      else
        first_l = "1| #{lines[0]}\n"
        first_l + lines[1..].map.with_index{ |l, i| line_num_temp(indent_num, i, l) }.join("\n")
      end
    end

    def line_num_temp(indent_num, index, line)
      "#{' ' * indent_num}#{index + 2}| #{line}"
    end

    def create_initialized_content
      <<~TEST
        # frozen_string_literal: true

        require_relative '../support/test_case'

        module DEBUGGER__
          #{create_scenario_and_program}
        end
      TEST
    end

    def make_content
      @target_src = File.read(@target_path)
      target = @target_src.gsub(/\r|\n|\s/, '')
      @inserted_src.scan(/<<~RUBY(.*?)RUBY/m).each do |p|
        return create_scenario + "\n  end" if p[0].gsub(/\r|\n|\s|\d+\|/, '') == target
      end
      "  end" + create_scenario_and_program
    end

    def file_name
      @class.sub(/(?i:t)est/, '').gsub(/([[:upper:]])/) {"_#{$1.downcase}"}.delete_prefix('_')
    end

    def create_file
      path = "#{__dir__}/../debug/#{file_name}_test.rb"
      if File.exist?(path)
        @inserted_src = File.read(path)
        content = @inserted_src.split("\n")[0..-3].join("\n") + "\n#{make_content}\nend\n" if @inserted_src.include? @class
      end
      if content
        puts "appended: #{path}"
      else
        content = create_initialized_content
        puts "created: #{path}"
        puts "    class: #{@class}"
      end
      puts "    method: #{@method}"

      File.write(path, content)
    end
  end

  class DAPTestBuilder < TestBuilderBase
    INDENT = '          '
    RUBY = ENV['RUBY'] || RbConfig.ruby
    RDBG_EXECUTABLE = "#{RUBY} #{__dir__}/../../exe/rdbg"

    def initialize(target, m, c)
      @target_path = File.absolute_path(target[0])
      @current_time = Time.now.to_i
      m = "test_#{@current_time}" if m.nil?
      @method = m
      c = 'FooTest' if c.nil?
      c_upcase = c.sub(/(^[a-z])/) { Regexp.last_match(1).upcase }
      if c_upcase.match? /(?i:t)est/
        @class = c_upcase
      else
        @class = "#{c_upcase}Test"
      end
    end

    def start
      activate_debugger
      create_file
    end

    def activate_debugger
      ENV['DEBUG_DAP_SHOW_PROTOCOL'] = '1'

      @scenario = []
      req_cfg_done = false
      res_cfg_done = false
      Open3.popen3("#{RDBG_EXECUTABLE} --open=vscode -- #{@target_path}") {|stdin, stdout, stderr, wait_thr|
        while data = stderr.gets
          case data
          when /\[\>\]\s(.*)/
            begin
              req = JSON.parse $1
            rescue JSON::ParserError
              next
            end
            unless req_cfg_done
              req_cfg_done = true if req['command'] == 'configurationDone'
              next
            end

            sorted_req = {'seq'=> req['seq']}
            sorted_req.merge! req
            @scenario << format_req(sorted_req)
          when /\[\<\]\s(.*)/
            begin
              res = JSON.parse $1
            rescue JSON::ParserError
              next
            end
            unless res_cfg_done
              res_cfg_done = true if req['command'] == 'configurationDone'
              next
            end

            sorted_res = {'seq'=> res['seq']}
            sorted_res.merge! res
            @scenario << format_res(sorted_res)
          else
            $stderr.print data
          end
        end
      }
    rescue EOFError
    end

    def format_res hash
      protocol = JSON.pretty_generate(hash).split("\n")
      "#{protocol[0]}\n" + protocol[1..].map{|p|
        src = p.sub(/"(.*)":\s/) {"#{$1}: "}
        case src
        when /(.*)"#{@target_path}"(,?)/
          src = "#{$1}/\#{temp_file_path}/#{$2}"
        when /(.*)"(.*)#{@target_path}.*"(,?)/
          src = "#{$1}/#{$2}.*/#{$3}"
        when /(.*)"#{File.basename @target_path}"(,?)/
          src = "#{$1}/\#{File.basename temp_file_path}/#{$2}"
        when /(.*)null(.*)/
          src = "#{$1}nil#{$2}"
        when /(.*):\s"(.*?)CatchBreakpoint:.*"(,?)/
          src = "#{$1}: /#{$2}CatchBreakpoint:.*/#{$3}"
        when /(.*)namedVariables:\s\d+(,?)/
          src = "#{$1}namedVariables: /\\d+/#{$2}"
        end
        "#{INDENT}#{src}"
      }.join("\n")
    end

    def format_req hash
      protocol = JSON.pretty_generate(hash).split("\n")
      "#{protocol[0]}\n" + protocol[1..].map{|p|
        src = p.sub(/"(.*)":\s/) {"#{$1}: "}
        case src
        when /(.*)"#{@target_path}"(.*)/
          src = "#{$1}temp_file_path#{$2}"
        when /(.*)"#{File.expand_path('../../exe/rdbg', __dir__)}"(,?)/
          src = "#{$1}/\#{File.expand_path('../../exe/rdbg', __dir__)}/#{$2}"
        when /(.*)null(.*)/
          src = "#{$1}nil#{$2}"
        end
        "#{INDENT}#{src}"
      }.join("\n")
    end

    def format_scenario
      first_s = "#{@scenario[0]},\n"
      first_s + @scenario[1..].map{|s|
        "#{INDENT}#{s}"
      }.join(",\n")
    end

    def create_scenario
      <<-TEST.chomp

    def #{@method}
      run_dap_scenario PROGRAM do
        [
          *INITIALIZE_MSG,
          #{format_scenario}
        ]
      end
    end
      TEST
    end

    def create_scenario_and_program
      <<-TEST.chomp

  class #{@class}#{@current_time} < TestCase
    PROGRAM = <<~RUBY
      #{format_program}
    RUBY
    #{create_scenario}
  end
      TEST
    end

    def format_program
      src = @target_src || File.read(@target_path)
      lines = src.split("\n")
      indent_num = 6
      if lines.length > 9
        first_l = " 1| #{lines[0]}\n"
        first_l + lines[1..].map.with_index{|l, i|
          if i < 8
            line_num_temp(indent_num + 1, i, l)
          else
            line_num_temp(indent_num, i, l)
          end
        }.join("\n")
      else
        first_l = "1| #{lines[0]}\n"
        first_l + lines[1..].map.with_index{ |l, i| line_num_temp(indent_num, i, l) }.join("\n")
      end
    end

    def line_num_temp(indent_num, index, line)
      "#{' ' * indent_num}#{index + 2}| #{line}"
    end

    def create_initialized_content
      <<~TEST
        # frozen_string_literal: true

        require_relative '../support/test_case'

        module DEBUGGER__
          #{create_scenario_and_program}
        end
      TEST
    end

    def make_content
      @target_src = File.read(@target_path)
      target = @target_src.gsub(/\r|\n|\s/, '')
      @inserted_src.scan(/<<~RUBY(.*?)RUBY/m).each do |p|
        return create_scenario + "\n  end" if p[0].gsub(/\r|\n|\s|\d+\|/, '') == target
      end
      "  end" + create_scenario_and_program
    end

    def file_name
      @class.sub(/(?i:t)est/, '').gsub(/([[:upper:]])/) {"_#{$1.downcase}"}.delete_prefix('_')
    end

    def create_file
      path = "#{__dir__}/../dap/#{file_name}_test.rb"
      if File.exist?(path)
        @inserted_src = File.read(path)
        content = @inserted_src.split("\n")[0..-3].join("\n") + "\n#{make_content}\nend\n" if @inserted_src.include? @class
      end
      if content
        puts "appended: #{path}"
      else
        content = create_initialized_content
        puts "created: #{path}"
        puts "    class: #{@class}"
      end
      puts "    method: #{@method}"

      File.write(path, content)
    end
  end
end
