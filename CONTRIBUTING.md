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

## Manually Test Your Changes

You can manually test your changes with a simple Ruby script + a line of command. The following example will help you check:

- Breakpoint insertion.
- Resume from the breakpoint.
- Backtrace display.
- Information (local variables, ivars..etc.) display.
- Debugger exit.


### Script

```ruby
# target.rb
class Foo
  def first_call
    second_call(20)
  end

  def second_call(num)
    third_call_with_block do |ten|
      forth_call(num, ten)
    end
  end

  def third_call_with_block(&block)
    @ivar1 = 10; @ivar2 = 20

    yield(10)
  end

  def forth_call(num1, num2)
    num1 + num2
  end
end

Foo.new.first_call
```

### Command

```
$ exe/rdbg -e 'b 20;; c ;; bt ;; info ;; q!' -e c target.rb
```

### Expect Result

```
❯ exe/rdbg -e 'b 20;; c ;; bt ;; info ;; q!' -e c target.rb
[1, 10] in target.rb
=>    1| class Foo
      2|   def first_call
      3|     second_call(20)
      4|   end
      5|
      6|   def second_call(num)
      7|     third_call_with_block do |ten|
      8|       forth_call(num, ten)
      9|     end
     10|   end
=>#0    <main> at target.rb:1
(rdbg:init) b 20
#1 line bp /PATH_TO_PROJECT/debug/target.rb:20 (return)
(rdbg:init) c
[15, 23] in target.rb
     15|     yield(10)
     16|   end
     17|
     18|   def forth_call(num1, num2)
     19|     num1 + num2
=>   20|   end
     21| end
     22|
     23| Foo.new.first_call
=>#0    Foo#forth_call(num1=20, num2=10) at target.rb:20 #=> 30
  #1    block{|ten=10|} in second_call at target.rb:8
  # and 4 frames (use `bt' command for all frames)

Stop by #1 line bp /PATH_TO_PROJECT/debug/target.rb:20 (return)
(rdbg:init) bt
=>#0    Foo#forth_call(num1=20, num2=10) at target.rb:20 #=> 30
  #1    block{|ten=10|} in second_call at target.rb:8
  #2    Foo#third_call_with_block(block=#<Proc:0x00007f8bc32f0c28 target.rb:7>) at target.rb:15
  #3    Foo#second_call(num=20) at target.rb:7
  #4    first_call at target.rb:3
  #5    <main> at target.rb:23
(rdbg:init) info
=>#0    Foo#forth_call(num1=20, num2=10) at target.rb:20 #=> 30
 %self => #<Foo:0x00007f8bc32f0ed0>
 %return => 30
 num1 => 20
 num2 => 10
 @ivar1 => 10
 @ivar2 => 20
(rdbg:init) q!
```
