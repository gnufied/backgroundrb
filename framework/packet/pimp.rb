module Packet
  class Pimp
    include NbioHelper
    extend ClassHelpers
    extend Forwardable
    iattr_accessor :pimp_name
    attr_accessor :lifeline, :pid, :signature
    attr_accessor :fd_write_end
    attr_accessor :workers, :reactor

    def initialize(lifeline_socket,worker_pid,p_reactor)
      @lifeline = lifeline_socket
      @pid = worker_pid
      @reactor = p_reactor
      @signature = Guid.hexdigest
      pimp_init if self.respond_to?(:pimp_init)
    end

    # encode the data, before writing to the socket
    def send_data p_data
      dump_object(p_data,@lifeline)
    end

    def send_fd sock_fd
      @fd_write_end.send_io(sock_fd)
    end

    alias_method :do_work, :send_data
    def_delegators :@reactor, :connections
  end
end

