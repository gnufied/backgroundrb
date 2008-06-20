# class stores connections to BackgrounDRb servers in a cluster manner
module BackgrounDRb
  class ClusterConnection
    attr_accessor :backend_connections,:config,:cache

    def initialize
      @bdrb_servers = []
      @backend_connections = []
      initialize_memcache if BDRB_CONFIG[:backgroundrb][:result_storage] == :memcache
      establish_connections
      @round_robin = (0...@backend_connections.length).to_a
    end

    def initialize_memcache
      require 'memcache'
      memcache_options = {
        :c_threshold => 10_000,
        :compression => true,
        :debug => false,
        :namespace => 'backgroundrb_result_hash',
        :readonly => false,
        :urlencode => false
      }
      @cache = MemCache.new(memcache_options)
      @cache.servers = BDRB_CONFIG[:memcache].split(',')
    end

    # initialize all backend server connections
    def establish_connections
      if t_servers = BDRB_CONFIG[:client]
        connections = t_servers.split(',')
        connections.each do |conn_string|
          ip = conn_string.split(':')[0]
          port = conn_string.split(':')[1].to_i
          @bdrb_servers << OpenStruct.new(:ip => ip,:port => port)
        end
      else
        @bdrb_servers << OpenStruct.new(:ip => BDRB_CONFIG[:backgroundrb][:ip],:port => BDRB_CONFIG[:backgroundrb][:port].to_i)
      end
      @bdrb_servers.each_with_index do |connection_info,index|
        @backend_connections << Connection.new(connection_info.ip,connection_info.port,self)
      end
    end # end of method establish_connections

    def worker(worker_name,worker_key = nil)
      chosen = choose_server
      chosen.worker(worker_name,worker_key)
    end

    def all_worker_info
      info_data = {}
      @backend_connections.each do |t_connection|
        info_data[t_connection.server_info] = t_connection.all_worker_info
      end
      return info_data
    end

    def new_worker options = {}
      chosen = choose_server
      chosen.new_worker(options)
    end

    def choose_server
      if @round_robin.empty?
        @round_robin = (0...@backend_connections.length).to_a
      end
      @backend_connections[@round_robin.shift]
    end
  end # end of ClusterConnection
end # end of Module BackgrounDRb
