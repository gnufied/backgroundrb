# class implements a simple callback mechanism for invoking callbacks
module Packet
  class Callback
    attr_accessor :signature,:stored_proc
    def initialize(&block)
      @signature = Guid.hexdigest
      @stored_proc = block
    end

    def invoke(*args)
      @stored_proc.call(*args)
    end
  end
end
