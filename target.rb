require "debug/command_register"

DEBUGGER__.regsiter_command("rails", "r") do |command|
  command.in_session do |ui, arg|
    case arg
    when nil
      ui.puts "you need to provide a sub-command"
    when "configs"
      ui.puts "!!!!!!!"
    end
  end
end

require "debug"

binding.bp
