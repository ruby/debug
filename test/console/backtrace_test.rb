# frozen_string_literal: true

require_relative '../support/console_test_case'

module DEBUGGER__
  class BasicBacktraceTest < ConsoleTestCase
    def program
      <<~RUBY
     1| class Foo
     2|   def first_call
     3|     second_call(20)
     4|   end
     5|
     6|   def second_call(num)
     7|     third_call_with_block do |ten|
     8|       num + ten
     9|     end
    10|   end
    11|
    12|   def third_call_with_block(&block)
    13|     yield(10)
    14|   end
    15| end
    16|
    17| [1, 2, 3].each do
    18|   Foo.new.first_call
    19| end
      RUBY
    end

    def test_backtrace_prints_c_method_frame
      debug_code(program) do
        type 'b 18'
        type 'c'
        type 'bt'
        assert_line_text(/\[C\] Array#each/)
        type 'kill!'
      end
    end

    def test_backtrace_prints_the_return_value
      debug_code(program) do
        type 'b 4'
        type 'c'
        type 'bt'
        assert_line_text(/Foo#first_call .* #=> 30/)
        type 'kill!'
      end
    end

    def test_backtrace_prints_method_arguments
      debug_code(program) do
        type 'b 7'
        type 'c'
        type 'bt'
        assert_line_text(/Foo#second_call\(num=20\)/)
        type 'kill!'
      end
    end

    def test_backtrace_prints_block_arguments
      debug_code(program) do
        type 'b 9'
        type 'c'
        type 'bt'
        assert_line_text(/block {\|ten=10\|}/)
        type 'kill!'
      end
    end

    def test_backtrace_prints_a_given_number_of_traces
      debug_code(program) do
        type 'b 13'
        type 'c'
        type 'bt 2'
        assert_line_text(/Foo#third_call_with_block/)
        assert_line_text(/Foo#second_call/)
        assert_no_line_text(/Foo#first_call/)
        type 'kill!'
      end
    end

    def test_backtrace_filters_traces_with_location
      debug_code(program) do
        type 'b 13'
        type 'c'
        type 'bt /rb:\d\z/'
        assert_line_text(/Foo#second_call/)
        assert_line_text(/Foo#first_call/)
        assert_no_line_text(/Foo#third_call_with_block/)
        type 'kill!'
      end
    end

    def test_backtrace_filters_traces_with_method_name
      debug_code(program) do
        type 'b 13'
        type 'c'
        type 'bt /second/'
        assert_line_text(/Foo#second_call/)
        assert_no_line_text(/Foo#first_call/)
        assert_no_line_text(/Foo#third_call_with_block/)
        type 'kill!'
      end
    end

    def test_backtrace_takes_both_number_and_pattern
      debug_code(program) do
        type 'b 13'
        type 'c'
        type 'bt 1 /rb:\d\z/'
        assert_line_text(/Foo#second_call/)
        assert_no_line_text(/Foo#first_call/)
        type 'kill!'
      end
    end

    def test_frame_filtering_works_with_unexpanded_path_and_expanded_skip_path
      foo_path = "#{pty_home_dir}/foo_#{Time.now.to_i}.rb"
      foo_file = <<~RUBY
        class Foo
          def bar
            debugger
          end
        end
      RUBY

      program = <<~RUBY
       1| load "~/#{File.basename(foo_path)}"
       2| Foo.new.bar
      RUBY

      begin
        File.open(foo_path, 'w+').close
      rescue Errno::EACCES, Errno::EPERM
        omit "Skip test with load files. Cannot create files in HOME directory."
      end

      File.open(foo_path, 'w+') { |f| f.write(foo_file) }
      debug_code(program) do
        type 'c'
        type 'bt'
        assert_line_text(/Foo#bar/)
        assert_line_text(/~\/foo_\d+.rb/)
        type "eval DEBUGGER__::CONFIG[:skip_path] = '#{foo_path}'"
        type 'bt'
        assert_no_line_text(/Foo#bar/) # ~/foo....rb should match foo.rb's absolute path and be skipped
        assert_no_line_text(/~\/foo\.rb/)
        type 'c'
      end
    ensure
      if File.exist? foo_path
        File.unlink foo_path
      end
    end
  end

  class BlockTraceTest < ConsoleTestCase
    def program
      <<~RUBY
     1| tap do
     2|   tap do
     3|     p 1
     4|   end
     5| end
     6|
     7| __END__
      RUBY
    end

    def test_backtrace_prints_block_label_correctly
      debug_code(program) do
        type 'b 2'
        type 'c'
        type 'bt'
        assert_line_text(/block in <main> at/)
        type 'kill!'
      end
    end

    def test_backtrace_prints_nested_block_label_correctly
      debug_code(program) do
        type 'b 3'
        type 'c'
        type 'bt'
        assert_line_text(/block in <main> \(2 levels\) at/)
        type 'kill!'
      end
    end
  end

   class ThreadLockingTraceTest < ConsoleTestCase
    def program
      <<~RUBY
     1| th0 = Thread.new{sleep}
     2| $m = Mutex.new
     3| th1 = Thread.new do
     4|   $m.lock
     5|   sleep 1
     6|   $m.unlock
     7| end
     8|
     9| o = Object.new
    10| def o.inspect
    11|   $m.lock
    12|   "foo".tap { $m.unlock }
    13| end
    14|
    15| def foo(o)
    16|  debugger
    17| end
    18| sleep 0.5
    19| foo(o)
      RUBY
    end

    def test_backtrace_prints_without_hanging
      debug_code(program) do
        type "c"

        type "bt"
        assert_line_text(/Object#foo\(o=foo\)/)
        type "bt"
        assert_line_text(/Object#foo\(o=foo\)/)
        type "bt"
        assert_line_text(/Object#foo\(o=foo\)/)

        type "kill!"
      end
    end
  end
end
