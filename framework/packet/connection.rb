# FIMXE: following class must modify the fd_watchlist thats being monitored by
# main eventloop.

module Packet
  module Connection
    def send_data p_data
      begin
        write_data(p_data,connection)
      rescue DisconnectError => sock_error
        close_connection
      end
    end

    def invoke_init
      @initialized = true
      post_init if respond_to?(:post_init)
    end

    def close_connection
      unbind if respond_to?(:unbind)
      reactor.remove_connection(connection)
    end

    def close_connection_after_writing
      connection.flush
      close_connection
    end

    def send_object p_object
      dump_object(p_object,connection)
    end
  end # end of class Connection
end # end of module Packet
