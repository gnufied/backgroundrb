module Packet
  class CPUWorker < Packet::Worker
    @@worker_type = 'cpu'
    cattr_accessor :worker_type
    # this is the place where all the worker specific inititlization has to be done
    def worker_init
      @worker_started = true
    end

    def receive_data p_data
      p p_data
    end

    def receive_internal_data p_data
      p p_data
    end

  end
end
