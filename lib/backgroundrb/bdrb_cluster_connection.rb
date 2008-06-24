# class stores connections to BackgrounDRb servers in a cluster manner
module BackgrounDRb
  class ClusterConnection
    include ClientHelper
    attr_accessor :backend_connections,:config,:cache
    attr_accessor :disconnected_connections

    def initialize
      @bdrb_servers = []
#       @backend_connections = Packet::DoubleKeyedHash.new
#       @disconnected_connections = Packet::DoubleKeyedHash.new
      @backend_connections = []
      @disconnected_connections = {}

      @last_polled_time = Time.now
      @request_count = 0

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
        #t_connection = Connection.new(connection_info.ip,connection_info.port,self)
        # @backend_connections[t_connection.server_info,index] = t_connection
        @backend_connections << Connection.new(connection_info.ip,connection_info.port,self)
      end
    end # end of method establish_connections

    # every 10 request or 10 seconds it will try to reconnect to bdrb servers which were down
    def discover_server_periodically
      @disconnected_connections.each do |key,connection|
        connection.establish_connection
        if connection.connection_status
          @backend_connections << connection
          connection.close_connection
          @disconnected_connections[key] = nil
        end
      end
      @disconnected_connections.delete_if { |key,value| value.nil? }
      @round_robin = (0...@backend_connections.length).to_a
    end

    def find_next_except_these connections
      invalid_connections = @backend_connections.delete_if { |x| connections.include?(x.server_info) }
      @round_robin = (0...@backend_connections.length).to_a
      invalid_connections.each do |x|
        @disconnected_connections[x.server_info] = x
      end
      chosen = @backend_connections.detect { |x| !(connections.include?(x.server_info)) }
      raise NoServerAvailable.new("No BackgrounDRb server is found running") unless chosen
      chosen
    end

    def worker(worker_name,worker_key = nil)
#       if worker_key
#         return find_among_cluster worker_name,worker_key
#       else
#         chosen = choose_server
#         chosen.worker(worker_name,worker_key)
#       end
      update_stats
      RailsWorkerProxy.new(worker_name,worker_key,self)
    end

    def update_stats
      @request_count += 1
      discover_server_periodically if time_to_discover?
    end

    def time_to_discover?
      if((@request_count%10 == 0) or (Time.now > (@last_polled_time + 10.seconds)))
        @last_polled_time = Time.now
        return true
      else
        return false
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
      update_stats
      info_data = {}
      @backend_connections.each do |t_connection|
        info_data[t_connection.server_info] = t_connection.all_worker_info rescue nil
      end
      return info_data
    end

    # one of the backend connections are chosen and worker is started on it
    def new_worker options = {}
      update_stats
      #chosen = choose_server
      #       t_key = gen_worker_key(options[:worker],options[:worker_key])
      #       @cached_new_workers[t_key] ||= []
      #       @cached_new_workers[t_key] << chosen.server_info
      #       tried_connections = [chosen]
      #       begin
      #         chosen.new_worker(options)
      #       rescue BdrbConnError => e
      #         chosen = find_next_except_these(tried_connections)
      #         tried_connections << chosen
      #         retry
      #       end
      # Should succeed on at least one
      succeeded = false
      @backend_connections.each do |connection|
        begin
          connection.new_worker(options)
          succeeded = true
        rescue BdrbConnError; end
      end
      raise NoServerAvailable.new("No BackgrounDRb server is found running") unless succeeded
    end

    def choose_server
      if @round_robin.empty?
        @round_robin = (0...@backend_connections.length).to_a
      end
      if @round_robin.empty? && @backend_connections.empty?
        discover_server_periodically
        raise NoServerAvailable.new("No BackgrounDRb server is found running") if @round_robin.empty? && @backend_connections.empty?
      end
      @backend_connections[@round_robin.shift]
    end
  end # end of ClusterConnection
end # end of Module BackgrounDRb
