## Set Up a Development Environment

1. `$ git clone git@github.com:ruby/debug.git`
2. `$ bundle install`
3. `$ rake` - this will
    - Compile the C extension locally (which can also be done solely with `rake compile`).
    - Run tests.
    - Re-generate `README.md`.

If you spot any problem, please open an issue.

## Run Tests

### Run all tests

```bash
$ rake test
```

### Run specific test(s)


```bash
$ ruby test/debug/bp_test.rb # run all tests in the specified file
$ ruby test/debug/bp_test.rb -h # to see all the test options
```

## Generate Tests
There is a test generator in `debug.rb` project to make it easier to write tests.
### Quickstart
This section shows you how to create test file by test generator. For more advanced informations on creating tests, please take a look at [gentest options](#gentest-options). (You can also check by `$bin/gentest -h`)
#### 1. Create a target file for debuggee.
Let's say, we created `target.rb` which is located in top level directory of debugger.
```ruby
module Foo
  class Bar
    def self.a
      "hello"
    end
  end
  Bar.a
  bar = Bar.new
end
```
#### 2. Run `gentest` as shown in the example below.
```shell
$ bin/gentest target.rb
```
#### 3. Debugger will be executed. You can type any debug commands.
```shell
$ bin/gentest target.rb
[1, 9] in ~/workspace/debug/target.rb
=>    1| module Foo
      2|   class Bar
      3|     def self.a
      4|       "hello"
      5|     end
      6|   end
      7|   Bar.a
      8|   bar = Bar.new
      9| end
=>#0	<main> at ~/workspace/debug/target.rb:1
INTERNAL_INFO: {"location":"~/workspace/debug/target.rb:1","line":1}

(rdbg)s
 s
[1, 9] in ~/workspace/debug/target.rb
      1| module Foo
=>    2|   class Bar
      3|     def self.a
      4|       "hello"
      5|     end
      6|   end
      7|   Bar.a
      8|   bar = Bar.new
      9| end
=>#0	<module:Foo> at ~/workspace/debug/target.rb:2
  #1	<main> at ~/workspace/debug/target.rb:1
INTERNAL_INFO: {"location":"~/workspace/debug/target.rb:2","line":2}

(rdbg)n
 n
[1, 9] in ~/workspace/debug/target.rb
      1| module Foo
      2|   class Bar
=>    3|     def self.a
      4|       "hello"
      5|     end
      6|   end
      7|   Bar.a
      8|   bar = Bar.new
      9| end
=>#0	<class:Bar> at ~/workspace/debug/target.rb:3
  #1	<module:Foo> at ~/workspace/debug/target.rb:2
  #2	<main> at ~/workspace/debug/target.rb:1
INTERNAL_INFO: {"location":"~/workspace/debug/target.rb:3","line":3}

(rdbg)b 7
 b 7
INTERNAL_INFO: {"location":"~/workspace/debug/target.rb:3","line":3}

(rdbg)c
 c
[2, 9] in ~/workspace/debug/target.rb
      2|   class Bar
      3|     def self.a
      4|       "hello"
      5|     end
      6|   end
=>    7|   Bar.a
      8|   bar = Bar.new
      9| end
=>#0	<module:Foo> at ~/workspace/debug/target.rb:7
  #1	<main> at ~/workspace/debug/target.rb:1

Stop by #0  BP - Line  /Users/naotto/workspace/debug/target.rb:7 (line)
INTERNAL_INFO: {"location":"~/workspace/debug/target.rb:7","line":7}

(rdbg)q!
 q!
```
#### 4. The test file will be created as `test/debug/foo_test.rb`.
If the file already exists, **only method** will be added to it.
```ruby
# frozen_string_literal: true

require_relative '../support/test_case'

module DEBUGGER__
  class FooTest < TestCase
    def program
      <<~RUBY
        1| module Foo
        1|   class Bar
        2|     def self.a
        3|       "hello"
        4|     end
        5|   end
        6|   Bar.a
        7|   bar = Bar.new
        8| end
      RUBY
    end
    
    def test_foo
      debug_code(program) do
        type 's'
        assert_line_num 2
        assert_line_text([
          /[1, 9] in .*/,
          /      1| module Foo/,
          /=>    2|   class Bar/,
          /      3|     def self.a/,
          /      4|       "hello"/,
          /      5|     end/,
          /      6|   end/,
          /      7|   Bar.a/,
          /      8|   bar = Bar.new/,
          /      9| end/,
          /=>#0	<module:Foo> at .*/,
          /  #1	<main> at .*/
        ])
        type 'n'
        assert_line_num 3
        assert_line_text([
          /[1, 9] in .*/,
          /      1| module Foo/,
          /      2|   class Bar/,
          /=>    3|     def self.a/,
          /      4|       "hello"/,
          /      5|     end/,
          /      6|   end/,
          /      7|   Bar.a/,
          /      8|   bar = Bar.new/,
          /      9| end/,
          /=>#0	<class:Bar> at .*/,
          /  #1	<module:Foo> at .*/,
          /  #2	<main> at .*/
        ])
        type 'b 7'
        assert_line_text(//)
        type 'c'
        assert_line_num 7
        assert_line_text([
          /[2, 9] in .*/,
          /      2|   class Bar/,
          /      3|     def self.a/,
          /      4|       "hello"/,
          /      5|     end/,
          /      6|   end/,
          /=>    7|   Bar.a/,
          /      8|   bar = Bar.new/,
          /      9| end/,
          /=>#0	<module:Foo> at .*/,
          /  #1	<main> at .*/,
          //,
          /Stop by #0  BP - Line  .*/
        ])
        type 'q!'
      end
    end
  end
end
```

#### gentest options
You can get more information about `gentest` here.

The default method name is `test_foo` and the class name is `FooTest`. The file name will be `[Lowercase letters with "Test" removed from the class name]_test.rb`.
```shell
# run without any options(test method name will be `test_foo`, class name will be `FooTest`, file name will be `foo_test.rb`)
$ bin/gentest target.rb
# specify the class name(test method name will be `test_foo`, class name will be `StepTest`, file name will be `step_test.rb`)
$ bin/gentest target.rb -c StepTest
# specify the method name(test method name will be `test_step`, class name will be `FooTest`, file name will be `foo_test.rb`)
$ bin/gentest target.rb -m test_step
# specify class name and method name(test method name will be `test_step`, class name will be `StepTest`, file name will be `step_test.rb`.)
$ bin/gentest target.rb -c StepTest -m test_step
```

## To Update README

This project generates `README.md` from the template `misc/README.md.erb`

So **do not** directly update `README.md`. Instead, you should update the template's source and run

```bash
$ rake
```

to reflect the changes on `README.md`.


### When to re-generate `README.md`

- After updating `misc/README.md.erb`.
- After updating `rdbg` executable's options.
- After updating comments of debugger's commands.
