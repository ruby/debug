# TODO

## Basic functionality

* VScode DAP support
* Support Ractors
* Signal (SIGINT) support
* Remote connection with openssl

## UI

* Coloring
* Interactive breakpoint setting
* irb integration
* Web browser integrated UI

## Debug command

* Breakpoints
    * Lightweight pending method break points with Ruby 3.1 feature (TP:method_added)
    * Non-stop breakpoint but runs some code.
* Watch points
    * Lightweight watchpoints for instance variables with Ruby 3.1 features (TP:ivar_set)
* Faster `next`/`finish` command by specifying target code.
* `set`/`show` configurations
* In-memory line traces
* Timemachine debugging

## Tests

* Test framework
* Tests for commands
* Tests for remote debugging
