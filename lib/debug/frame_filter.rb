module DEBUGGER__
  class << self
    def inclusion_patterns
      @inclusion_patterns ||= []
    end

    def register_inclusion_pattern(pattern)
      inclusion_patterns << pattern
    end

    def exclusion_patterns
      @exclusion_patterns ||= []
    end

    def register_exclusion_pattern(pattern)
      exclusion_patterns << pattern
    end
  end
end
