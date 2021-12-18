require 'mkmf'
require_relative '../../lib/debug/version'
File.write("debug_version.h", "#define RUBY_DEBUG_VERSION \"#{DEBUGGER__::VERSION}\"\n")

check_func = -> (name, defn, call) do
  if try_link("#{defn}; int main(){ #{call}; return 0; }")
    $defs << "-DHAVE_#{name.upcase}"
  end
end

check_func.call "iseq_parameters",
                "VALUE rb_iseq_parameters(void *, int is_proc)",
                "rb_iseq_parameters(NULL, 0)"

check_func.call "iseq_code_location",
                "void rb_iseq_code_location(void *, int *first_lineno, int *first_column, int *last_lineno, int *last_column)",
                "rb_iseq_code_location(NULL, NULL, NULL, NULL, NULL)"

# from Ruby 3.1
check_func.call "iseq_type",
                "VALUE rb_iseq_type(void *)",
                "rb_iseq_type(NULL)"

create_makefile 'debug/debug'
