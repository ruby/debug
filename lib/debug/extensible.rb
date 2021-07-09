module DEBUGGER__
  def self.register_frame_filter(&block)
    @frame_filters ||= []
    @frame_filters << block
  end

  def self.frame_filters
    @frame_filters ||= []
  end
end
