module Packet
  class IOWorker < Packet::Worker
    @@worker_type = :io
    cattr_accessor :worker_type
  end
end
