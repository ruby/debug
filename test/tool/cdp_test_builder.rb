# frozen_string_literal: true

require 'json'
require 'open3'

module DEBUGGER__
  class CDPTestBuilder
    def initialize(target, m, c, p)
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
      @port = p || 0
    end

    def start
      run_test_scenario
      create_file
    end

    INDENT = '        '
    RUBY = RbConfig.ruby
    RDBG_EXECUTABLE = "#{RUBY} #{__dir__}/../../exe/rdbg"

    def run_test_scenario
      ENV['RUBY_DEBUG_CDP_SHOW_PROTOCOL'] = '1'

      @scenario = []
      Open3.popen3("#{RDBG_EXECUTABLE} --open=chrome --port #{@port} -- #{@target_path}") {|_, _, stderr, _|
        while data = stderr.gets
          case data
          when /\[>\](.*)/
            begin
              req = JSON.parse $1
            rescue JSON::ParserError
              next
            end
            # It's hard to write Runtime.getProperties in the test generator.
            if req['method'] == 'Runtime.getProperties'
              skip_id = req['id']
              next
            end
            @scenario.push "cdp_req(#{format_req req})"
          when /\[<\](.*)/
            begin
              res = JSON.parse $1
            rescue JSON::ParserError
              next
            end
            if res_id = res['id']
              next if res_id == skip_id

              @scenario.push "assert_cdp_res(#{format_res res})"
            else
              @scenario.push "assert_cdp_evt(#{format_res res})"
            end
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
        src = p.sub(/(".*(?i:i)d":\s)".+"/) {"#{Regexp.last_match(1)}/.+/"}
        src = src.sub(/("(hash|description|value|origin|url)":\s)".+"/) {"#{Regexp.last_match(1)}/.+/"}
        "#{INDENT}#{src}"
      }.join("\n")
    end

    def format_req hash
      protocol = JSON.pretty_generate(hash).split("\n")
      "#{protocol[0]}\n" + protocol[1..].map{|p|
        src = p.sub(/("url":\s"http\:\/\/debuggee).+"/) {"#{Regexp.last_match(1)}\#{temp_file_path}\""}
        src = src.sub(/("scriptId":\s)".+"/) {"#{Regexp.last_match(1)}/\#{temp_file_path}/"}
        src = src.sub(/("breakpointId":\s"\d+:\d+:).+"/) {"#{Regexp.last_match(1)}\#{temp_file_path}\""}
        "#{INDENT}#{src}"
      }.join("\n")
    end

    def create_scenario
      <<-TEST.chomp

    def #{@method}
      run_cdp_scenario PROGRAM do
        #{format_scenario}
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

    def format_scenario
      first_s = "#{@scenario[0]}\n"
      first_s + @scenario[1..].map{|s|
        "#{INDENT}#{s}"
      }.join("\n")
    end

    def make_content
      @target_src = File.read(@target_path)
      target = @target_src.gsub(/\r|\n|\s/, '')
      @inserted_src.scan(/<<~RUBY(.*?)RUBY/m).each do |p|
        return create_scenario + "\n  end" if p[0].gsub(/\r|\n|\s|\d+\|/, '') == target
      end
      "  end" + create_scenario_and_program
    end

    def create_file
      path = "#{__dir__}/../cdp/#{@class.sub(/(?i:t)est/, '').downcase}_test.rb"
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
