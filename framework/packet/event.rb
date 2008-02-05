module Packet
  class Event
    attr_accessor :timer_signature, :block, :cancel_flag
    def initialize(elapsed_time,&block)
      @cancel_flag = false
      @timer_signature = Guid.hexdigest
      @block = block
      @scheduled_time = Time.now + elapsed_time
    end

    def run_now?
      return true if @scheduled_time <= Time.now
      return false
    end

    def cancel
      @cancel_flag = true
    end

    def run
      @block.call
    end
  end
end
# WOW
