
module DEBUGGER__
  def self.unix_domain_socket_dir
    case
    when path = DEBUGGER__::CONFIG[:sock_dir]
    when path = ENV['XDG_RUNTIME_DIR']
    when home = ENV['HOME']
      path = File.join(home, '.ruby-debug-sock')

      case
      when !File.exist?(path)
        Dir.mkdir(path, 0700)
      when !File.directory?(path)
        raise "#{path} is not a directory."
      end
    else
      raise 'specify RUBY_DEBUG_SOCK_DIR environment variable for UNIX domain socket directory.'
    end

    path
  end

  def self.create_unix_domain_socket_name_prefix(base_dir = unix_domain_socket_dir)
    user = ENV['USER'] || 'ruby-debug'
    File.join(base_dir, "ruby-debug-#{user}")
  end

  def self.create_unix_domain_socket_name(base_dir = unix_domain_socket_dir)
    create_unix_domain_socket_name_prefix(base_dir) + "-#{Process.pid}"
  end

  CONFIG_MAP = {
    # execution preferences
    nonstop:     'RUBY_DEBUG_NONSTOP',     # Nonstop mode ('1' is nonstop)
    init_script: 'RUBY_DEBUG_INIT_SCRIPT', # debug command script path loaded at first stop
    commands:    'RUBY_DEBUG_COMMANDS',    # debug commands invoked at first stop. commands should be separated by ';;'
    show_src_lines: 'RUBY_DEBUG_SHOW_SRC_LINES', # Show n lines source code on breakpoint (default: 10 lines).
    show_frames:    'RUBY_DEBUG_SHOW_FRAMES',    # Show n frames on breakpoint (default: 2 frames).

    # remote
    port:        'RUBY_DEBUG_PORT',        # TCP/IP remote debugging: port
    host:        'RUBY_DEBUG_HOST',        # TCP/IP remote debugging: host (localhost if not given)
    sock_dir:    'RUBY_DEBUG_SOCK_DIR',    # UNIX Domain Socket remote debugging: socket directory
  }.freeze

  def self.config_to_env config
    CONFIG_MAP.each{|key, evname|
      ENV[evname] = config[key]
    }
  end

  def self.parse_argv argv
    config = {
      mode: :start,
    }
    CONFIG_MAP.each{|key, evname|
      config[key] = ENV[evname] if ENV[evname]
    }
    return config if !argv || argv.empty?

    require 'optparse'

    opt = OptionParser.new do |o|
      o.banner = "#{$0} [options] -- [debuggee options]"
      o.separator ''

      o.separator 'Debug console mode:'
      o.on('-n', '--nonstop', 'Do not stop at the beginning of the script.') do
        config[:nonstop] = '1'
      end

      o.on('-e [COMMAND]', 'execute debug command at the beginning of the script.') do |cmd|
        config[:commands] ||= ''
        config[:commands] << cmd + ';;'
      end

      o.on('-O', '--open', 'Start debuggee with opening the debugger port.',
                           'If TCP/IP options are not given,',
                           'a UNIX domain socket will be used.') do
        config[:remote] = true
      end
      o.on('--port=[PORT]', 'Listening TCP/IP port') do |port|
        config[:port] = port
      end
      o.on('--host=[HOST]', 'Listening TCP/IP host') do |host|
        config[:host] = host
      end

      o.separator ''
      o.separator '  Debug console mode runs Ruby program with the debug console.'
      o.separator ''
      o.separator "  #{$0} target.rb foo bar                 starts like 'ruby target.rb foo bar'."
      o.separator "  #{$0} -- -r foo -e bar                  starts like 'ruby -r foo -e bar'."
      o.separator "  #{$0} -O target.rb foo bar              starts and accepts attaching with UNIX domain socket."
      o.separator "  #{$0} -O --port 1234 target.rb foo bar  starts accepts attaching with TCP/IP localhost:1234."
      o.separator "  #{$0} -O --port 1234 -- -r foo -e bar   starts accepts attaching with TCP/IP localhost:1234."

      o.separator ''
      o.separator 'Attach mode:'
      o.on('-A', '--attach', 'Attach to debuggee process.') do
        config[:mode] = :attach
      end

      o.separator ''
      o.separator '  Attach mode attaches the remote debug console to the debuggee process.'
      o.separator ''
      o.separator "  '#{$0} -A' tries to connect via UNIX domain socket."
      o.separator "  #{' ' * $0.size}            If there are multiple processes are waiting for the"
      o.separator "  #{' ' * $0.size}            debugger connection, list possible debuggee names."
      o.separator "  '#{$0} -A path' tries to connect via UNIX domain socket with given path name."
      o.separator "  '#{$0} -A port' tries to connect localhost:port via TCP/IP."
      o.separator "  '#{$0} -A host port' tries to connect host:port via TCP/IP."
    end

    opt.parse!(argv)

    config
  end
end
