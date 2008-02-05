module Packet
  class PeriodicEvent
    attr_accessor :block, :timer_signature, :interval, :cancel_flag
    def initialize(interval, &block)
      @cancel_flag = false
      @timer_signature = Guid.hexdigest
      @block = block
      @scheduled_time = Time.now + interval
      @interval = interval
    end

    def run_now?
      return true if @scheduled_time <= Time.now
      return false
    end

    def cancel
      @cancel_flag = true
    end

    def run
      @scheduled_time += @interval
      @block.call
    end

  end
end
