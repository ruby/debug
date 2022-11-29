# Configuration

You can configure the debugger's behavior with the `config` command and environment variables.

Every configuration has a corresponding environment variable, for example:

```
config set log_level INFO # RUBY_DEBUG_LOG_LEVEL=INFO
config set no_color true  # RUBY_DEBUG_NO_COLOR=true
```



- UI
  - `RUBY_DEBUG_LOG_LEVEL` (`log_level`): Log level same as Logger (default: WARN)
  - `RUBY_DEBUG_SHOW_SRC_LINES` (`show_src_lines`): Show n lines source code on breakpoint (default: 10)
  - `RUBY_DEBUG_SHOW_FRAMES` (`show_frames`): Show n frames on breakpoint (default: 2)
  - `RUBY_DEBUG_USE_SHORT_PATH` (`use_short_path`): Show shorten PATH (like $(Gem)/foo.rb) (default: false)
  - `RUBY_DEBUG_NO_COLOR` (`no_color`): Do not use colorize (default: false)
  - `RUBY_DEBUG_NO_SIGINT_HOOK` (`no_sigint_hook`): Do not suspend on SIGINT (default: false)
  - `RUBY_DEBUG_NO_RELINE` (`no_reline`): Do not use Reline library (default: false)
  - `RUBY_DEBUG_NO_HINT` (`no_hint`): Do not show the hint on the REPL (default: false)

- CONTROL
  - `RUBY_DEBUG_SKIP_PATH` (`skip_path`): Skip showing/entering frames for given paths
  - `RUBY_DEBUG_SKIP_NOSRC` (`skip_nosrc`): Skip on no source code lines (default: false)
  - `RUBY_DEBUG_KEEP_ALLOC_SITE` (`keep_alloc_site`): Keep allocation site and p, pp shows it (default: false)
  - `RUBY_DEBUG_POSTMORTEM` (`postmortem`): Enable postmortem debug (default: false)
  - `RUBY_DEBUG_FORK_MODE` (`fork_mode`): Control which process activates a debugger after fork (both/parent/child) (default: both)
  - `RUBY_DEBUG_SIGDUMP_SIG` (`sigdump_sig`): Sigdump signal (default: false)

- BOOT
  - `RUBY_DEBUG_NONSTOP` (`nonstop`): Nonstop mode (default: false)
  - `RUBY_DEBUG_STOP_AT_LOAD` (`stop_at_load`): Stop at just loading location (default: false)
  - `RUBY_DEBUG_INIT_SCRIPT` (`init_script`): debug command script path loaded at first stop
  - `RUBY_DEBUG_COMMANDS` (`commands`): debug commands invoked at first stop. commands should be separated by ';;'
  - `RUBY_DEBUG_NO_RC` (`no_rc`): ignore loading ~/.rdbgrc(.rb) (default: false)
  - `RUBY_DEBUG_HISTORY_FILE` (`history_file`): history file (default: ~/.rdbg_history)
  - `RUBY_DEBUG_SAVE_HISTORY` (`save_history`): maximum save history lines (default: 10000)

- REMOTE
  - `RUBY_DEBUG_OPEN` (`open`): Open remote port (same as `rdbg --open` option)
  - `RUBY_DEBUG_PORT` (`port`): TCP/IP remote debugging: port
  - `RUBY_DEBUG_HOST` (`host`): TCP/IP remote debugging: host (default: 127.0.0.1)
  - `RUBY_DEBUG_SOCK_PATH` (`sock_path`): UNIX Domain Socket remote debugging: socket path
  - `RUBY_DEBUG_SOCK_DIR` (`sock_dir`): UNIX Domain Socket remote debugging: socket directory
  - `RUBY_DEBUG_LOCAL_FS_MAP` (`local_fs_map`): Specify local fs map
  - `RUBY_DEBUG_SKIP_BP` (`skip_bp`): Skip breakpoints if no clients are attached (default: false)
  - `RUBY_DEBUG_COOKIE` (`cookie`): Cookie for negotiation
  - `RUBY_DEBUG_CHROME_PATH` (`chrome_path`): Platform dependent path of Chrome (For more information, See [here](https://github.com/ruby/debug/pull/334/files#diff-5fc3d0a901379a95bc111b86cf0090b03f857edfd0b99a0c1537e26735698453R55-R64))

- OBSOLETE
  - `RUBY_DEBUG_PARENT_ON_FORK` (`parent_on_fork`): Keep debugging parent process on fork (default: false)

There are other environment variables:

* `NO_COLOR`: If the value is set, set `RUBY_DEBUG_NO_COLOR` ([NO_COLOR: disabling ANSI color output in various Unix commands](https://no-color.org/)).
* `RUBY_DEBUG_ENABLE`: If the value is `0`, do not enable debug.gem feature.
* `RUBY_DEBUG_ADDED_RUBYOPT`: Remove this value from `RUBYOPT` at first. This feature helps loading debug.gem with `RUBYOPT='-r debug/...'` and you don't want to derive it to child processes. In this case you can set `RUBY_DEBUG_ADDED_RUBYOPT='-r debug/...'` (same value) and this string will be deleted from `RUBYOPT` at first.
* `RUBY_DEBUG_EDITOR` or `EDITOR`: An editor used by `edit` debug command.
* `RUBY_DEBUG_BB`: Define `Kernel#bb` method which is alias of `Kernel#debugger`.

## Initialization scripts

If you want to run certain commands or set configurations for every debugging session automatically, you can put them into the `~/.rdbgrc` file.

If you want to run additional initial scripts, you can also,

- Use `RUBY_DEBUG_INIT_SCRIPT` environment variable can specify the initial script file.
- Specify the initial script with `rdbg -x initial_script`.

Initial scripts are useful to write your favorite configurations.  For example,

```
config set use_short_path true # Use $(Gem)/gem_content to replace the absolute path of gem files
```

Finally, you can also write the initial script in Ruby with the file name `~/.rdbgrc.rb`.
