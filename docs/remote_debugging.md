# Introduction

Remote debugging with Ruby debugger means:

1. Invoke your program as a remote debuggee.
2. Connect the debuggee to supported platforms:
    - Debugger console
    - [VSCode](#vscode) (or other DAP supporting clients)
    - [Chrome DevTools](#chrome-devtool-integration) (or other CDP supporting clients)

## Quick Start with VSCode or Chrome DevTools

If you use VSCode or Chrome DevTools **and** are running the program and debugger in the same environment (e.g. on the same machine without using container), `--open` flag can do both steps 1 and 2 for you.

For example:

```shell
$ rdbg --open=vscode target.rb
# chrome users can specify --open=chrome instead
```

It will open a debug port, launch VSCode, and attach to it automatically.

# Invoke Program As A Remote Debuggee

There are multiple ways to run your program as a debuggee:

Stop at program start | [`rdbg` option](#rdbg---open-or-rdbg--o-for-short) | [require](#require-debugopen) | [debugger API](#debuggeropen)
---|---|---|---|
Yes | `rdbg --open` | `require "debug/open"` | `DEBUGGER__.open`
No | `rdbg --open --nonstop` | `require "debug/open_nonstop"` | `DEBUGGER__.open(nonstop: true)`

## `rdbg --open` (or `rdbg -O` for short)

When `--open` flag is used without specifying a client, it'll start the program as remote debuggee and wait for the connection:

```shell
$ rdbg --open target.rb
DEBUGGER: Session start (pid: 7773)
DEBUGGER: Debugger can attach via UNIX domain socket (/home/ko1/.ruby-debug-sock/ruby-debug-ko1-7773)
DEBUGGER: wait for debugger connection...
```

By default, `rdbg --open` uses UNIX domain socket and generates path name automatically (`/home/ko1/.ruby-debug-sock/ruby-debug-ko1-7773` in this case).

## `require 'debug/open'`

If you can modify the program, you can open a debugging port by adding `require 'debug/open'` to the program.

If you don't want to stop the program when `require 'debug/open'` is executed, you can instead use `require 'debug/open_nonstop'`.

> **Note**
> Please do not leave these requires in your program as they will allow other people to connect to it.

## `DEBUGGER__.open`

After requiring `debug/session`, you can start a debug session using the following methods.
They are convenient if you want to specify debug configurations with Ruby code.

- `DEBUGGER__.open(**kw)`: opens a debug port using the specified configuration (by default opens a UNIX domain socket).
- `DEBUGGER__.open_unix(**kw)`: opens a debug port through UNIX domain socket.
- `DEBUGGER__.open_tcp(**kw)`: opens a debug port through TCP/IP.

For example:

```ruby
require 'debug/session'
DEBUGGER__.open

# your application code
```

## TCP/IP

If you want to use TCP/IP for remote debugging, you need to specify the port and host through the `--port` and `--host` flags:

```shell
rdbg --open --port 12345 # binds to 127.0.0.1:12345
rdbg --open --port 12345 --host myhost.dev # binds to myhost.dev:12345
```

Alternatively, you can also specify port and host with `RUBY_DEBUG_PORT` and `RUBY_DEBUG_HOST` environment variables:

```shell
$ RUBY_DEBUG_PORT=12345 RUBY_DEBUG_HOST=localhost ruby target.rb
```

# Connect To A Remote Debuggee

## Debugger Console

You can connect to the debuggee with `rdbg --attach` command (`rdbg -A` for short).

```shell
$ rdbg --attach
[1, 7] in target.rb
=>    1| a = 1
      2| b = 2
      3| c = 3
      4| d = 4
      5| p [a, b, c, d]
      6|
      7| __END__
=>#0    <main> at target.rb:1

(rdbg:remote)
```

If there is only one opened UNIX domain socket in the socket directory, `rdbg --attach` will connect to it automatically.

If there are more than one socket files, you need to specify the socket name after the `--attach` flag:

```shell
❯ rdbg --attach
Please select a debug session:
  ruby-debug-st0012-64507
  ruby-debug-st0012-68793

❯ rdbg --attach ruby-debug-st0012-64507
[1, 1] in target.rb
=>   1| a = 1
=>#0    <main> at target.rb:1
(rdbg:remote)
```

When `rdbg --attach` connects to the debuggee, you can use debugger commands like in a local debugger console. When a debuggee program exits, the remote console will also terminate.

> **Note**
> If you use the `quit` command, only the remote console exits and the debuggee program continues to run (and you can connect to it again). If you want to exit the debuggee program as well, use the `kill` command instead.

### Through TCP/IP

To connect to the debuggee via TCP/IP, you need to specify the port.

```shell
$ rdbg --attach 12345
```

If you want to choose the host to bind, you can use the `--host` option.

> **Note**
> The connection between the debugger and the debuggee is **NOT** encrypted. So please use remote debugging carefully.

## VSCode

You can use this debugger with VSCode. First, install the [VSCode rdbg Ruby Debugger](https://marketplace.visualstudio.com/items?itemName=KoichiSasada.vscode-rdbg) extension (`v0.0.9` or later is required).

You can configure the extension in `.vscode/launch.json`. Please see the extension page for more details.

You can also check [Debugging in Visual Studio Code](https://code.visualstudio.com/docs/editor/debugging) for more information about VSCode's debugger features.

### Start The Debuggee Program From VSCode

1. Open a `.rb` file (e.g. `target.rb`)
1. Register breakpoints using "Toggle breakpoint" in the `Run` menu (or press F9)
1. Choose "Start debugging" in the `Run` menu (or press F5)
1. You will see a dialog "Debug command line" and you can choose your favorite command line your want to run.
1. Chosen command line is invoked with `rdbg -c` and VSCode shows the details at breakpoints.

### The `open` Command

You can use `open vscode` command in REPL, which is the same as `--open=vscode`.

```shell
$ rdbg target.rb
[1, 8] in target.rb
     1|
=>   2| p a = 1
     3| p b = 2
     4| p c = 3
     5| p d = 4
     6| p e = 5
     7|
     8| __END__
=>#0    <main> at target.rb:2
(rdbg) open vscode    # command
DEBUGGER: wait for debugger connection...
DEBUGGER: Debugger can attach via UNIX domain socket (/tmp/ruby-debug-sock-1000/ruby-debug-ko1-28337)
Launching: code /tmp/ruby-debug-vscode-20211014-28337-kg9dm/ /tmp/ruby-debug-vscode-20211014-28337-kg9dm/README.rb
DEBUGGER: Connected.
```

If the environment doesn't have a `code` command, the following message will be shown:

```shell
(rdbg) open vscode
DEBUGGER: wait for debugger connection...
DEBUGGER: Debugger can attach via UNIX domain socket (/tmp/ruby-debug-sock-1000/ruby-debug-ko1-455)
Launching: code /tmp/ruby-debug-vscode-20211014-455-gtjpwi/ /tmp/ruby-debug-vscode-20211014-455-gtjpwi/README.rb
DEBUGGER: Can not invoke the command.
Use the command-line on your terminal (with modification if you need).

  code /tmp/ruby-debug-vscode-20211014-455-gtjpwi/ /tmp/ruby-debug-vscode-20211014-455-gtjpwi/README.rb

If your application is running on a SSH remote host, please try:

  code --remote ssh-remote+[SSH hostname] /tmp/ruby-debug-vscode-20211014-455-gtjpwi/ /tmp/ruby-debug-vscode-20211014-455-gtjpwi/README.rb

```

## Chrome DevTool integration

With `rdbg --open=chrome` command will show the following message.

```shell
$ rdbg --open=chrome target.rb
DEBUGGER: Debugger can attach via TCP/IP (127.0.0.1:43633)
DEBUGGER: With Chrome browser, type the following URL in the address-bar:

   devtools://devtools/bundled/inspector.html?ws=127.0.0.1:43633

DEBUGGER: wait for debugger connection...
```

Type `devtools://devtools/bundled/inspector.html?ws=127.0.0.1:43633` in the address-bar on Chrome browser, and you can continue the debugging with chrome browser.

You can use the `open chrome` command in a `rdbg` console to open the debug session in Chrome.

For more information about how to use Chrome debugging, refer to [the documentation for Chrome DevTools](https://developer.chrome.com/docs/devtools/).
