require 'securerandom'

module DEBUGGER__
  module ExtraFileHelper
    def with_extra_tempfile
      t = Tempfile.create([SecureRandom.hex(5), '.rb']).tap do |f|
        f.write(extra_file)
        f.close
      end
      yield t
    ensure
      File.unlink t if t
    end
  end
end
