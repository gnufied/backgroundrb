# class stores connections to BackgrounDRb servers in a cluster manner
module BackgrounDRb
  class ClusterConnection
    attr_accessor :backend_connections,:config
    def initialize
      @config = BackgrounDRb::Config.read_config("#{BACKGROUNDRB_ROOT}/config/backgroundrb.yml")
      @bdrb_servers = []
      @backend_connections = []
      @round_robin = []
      establish_connections
    end

    # initialize all backend server connections
    def establish_connections
      if t_servers = @config[:client]
        connections = t_servers.split(',')
        connections.each do |conn_string|
          ip = conn_string.split(':')[0]
          port = conn_string.split(':')[1].to_i
          @bdrb_servers << OpenStruct.new(:ip => ip,:port => port)
        end
      else
        @bdrb_servers << OpenStruct.new(:ip => @config[:backgroundrb][:ip],:port => @config[:backgroundrb][:port].to_i)
      end
      @bdrb_servers.each_with_index do |connection_info,index|
        @backend_connections << Connection.custom_connection(connection_info.ip,connection_info.port)
      end
    end # end of method establish_connections

    def worker(worker_name,worker_key = nil)
      chosen = choose_server
      chosen.worker(worker_name,worker_key)
    end

    def choose_server
      @round_robin = @backend_connections.dup if @round_robin.empty?
      @round_robin.shift
    end

  end
end
