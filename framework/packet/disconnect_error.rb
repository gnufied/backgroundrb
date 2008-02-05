module Packet
  class DisconnectError < RuntimeError
    attr_accessor :disconnected_socket,:data
    def initialize(t_sock,data = nil)
      @disconnected_socket = t_sock
      @data = data
    end
  end
end
