# class stores connections to BackgrounDRb servers in a cluster manner
module BackgrounDRb
  class ClusterConnection
    include ClientHelper
    attr_accessor :backend_connections,:config,:cache

    def initialize
      @bdrb_servers = []
      @backend_connections = Packet::DoubleKeyedHash.new
      initialize_memcache if BDRB_CONFIG[:backgroundrb][:result_storage] == 'memcache'
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
        t_connection = Connection.new(connection_info.ip,connection_info.port,self)
        @backend_connections[t_connection.server_info,index] = t_connection
      end
    end # end of method establish_connections

    def worker(worker_name,worker_key = nil)
      if worker_key
        return find_among_cluster worker_name,worker_key
      else
        chosen = choose_server
        chosen.worker(worker_name,worker_key)
      end
    end

    def find_among_cluster worker_name,worker_key
      t_key = gen_worker_key(worker_name,worker_key)
      if chosen_worker = delegate_to_new_worker(t_key)
        return chosen_worker
      else
        refresh_new_worker_cache
        return delegate_to_new_worker(t_key)
      end
    end

    def delegate_to_new_worker key
      t_connections = @cached_new_workers[t_key]
      return nil if t_connections.blank?
      first_connection = @backend_connections[t_connections[0]]
      first_connection.worker(worker_name,worker_key)
    end

    def refresh_new_worker_cache
      info_data = all_worker_info
      info_data.each do |key,value|
        value.each do |worker_status|
          next if worker_status[:worker_key].nil? or worker_status[:worker_key].empty?
          @cached_new_workers[worker_status[:worker_key]] ||= []
          @cached_new_workers[worker_status[:worker_key]] << key
        end
      end
    end

    def all_worker_info
      info_data = {}
      @backend_connections.each do |server_info,t_connection|
        info_data[server_info] = t_connection.all_worker_info
      end
      return info_data
    end

    # one of the backend connections are chosen and worker is started on it
    def new_worker options = {}
      chosen = choose_server
      t_key = gen_worker_key(options[:worker],options[:worker_key])
      @cached_new_workers[t_key] ||= []
      @cached_new_workers[t_key] << chosen.server_info
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
