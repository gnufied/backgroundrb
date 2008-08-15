module BackgrounDRb
  class RailsWorkerProxy
    attr_accessor :worker_name, :worker_method, :data, :worker_key,:middle_man

    def initialize(p_worker_name,p_worker_key = nil,p_middle_man = nil)
      @worker_name = p_worker_name
      @middle_man = p_middle_man
      @worker_key = p_worker_key
      @tried_connections = []
    end

    def method_missing(method_id,*args)
      worker_method = method_id.to_s
      arguments = args.first

      arg,job_key,host_info = arguments && arguments.values_at(:arg,:job_key,:host)

      if worker_method =~ /^async_(\w+)/
        method_name = $1
        worker_options = compact(:worker => worker_name,:worker_key => worker_key,
                                 :worker_method => method_name,:job_key => job_key, :arg => arg)
        run_method(host_info,:ask_work,worker_options)
      elsif worker_method =~ /^enq_(\w+)/i
        raise NoJobKey.new("Must specify a job key with enqueued tasks") if job_key.blank?
        method_name = $1
        marshalled_args = Marshal.dump(arg)
        enqueue_task(compact(:worker_name => worker_name.to_s,:worker_key => worker_key.to_s,
                             :worker_method => method_name.to_s,:job_key => job_key.to_s,
                             :args => marshalled_args,:timeout => arguments ? arguments[:timeout] : nil))
      else
        worker_options = compact(:worker => worker_name,:worker_key => worker_key,
                                 :worker_method => worker_method,:job_key => job_key,:arg => arg)
        run_method(host_info,:send_request,worker_options)
      end
    end

    def enqueue_task options = {}
      BdrbJobQueue.insert_job(options)
    end

    def run_method host_info,method_name,worker_options = {}
      result = []
      connection = choose_connection(host_info)
      raise NoServerAvailable.new("No BackgrounDRb server is found running") if connection.blank?
      if host_info == :local or host_info.is_a?(String)
        result << invoke_on_connection(connection,method_name,worker_options)
      elsif host_info == :all
        succeeded = false
        begin
          connection.each { |conn| result << invoke_on_connection(connection,method_name,worker_options) }
          succeeded = true
        rescue BdrbConnError; end
        raise NoServerAvailable.new("No BackgrounDRb server is found running") unless succeeded
      else
        @tried_connections = [connection.server_info]
        begin
          result << invoke_on_connection(connection,method_name,worker_options)
        rescue BdrbConnError => e
          connection = middle_man.find_next_except_these(@tried_connections)
          @tried_connections << connection.server_info
          retry
        end
      end
      return nil if method_name == :ask_work
      return_result(result)
    end

    def invoke_on_connection connection,method_name,options = {}
      raise NoServerAvailable.new("No BackgrounDRb is found running") unless connection
      connection.send(method_name,options)
    end

    def ask_result job_key
      options = compact(:worker => worker_name,:worker_key => worker_key,:job_key => job_key)
      if BDRB_CONFIG[:backgroundrb][:result_storage] == 'memcache'
        return_result_from_memcache(options)
      else
        result = middle_man.backend_connections.map { |conn| conn.ask_result(options) }
        return_result(result)
      end
    end

    def worker_info
      t_connections = middle_man.backend_connections
      result = t_connections.map { |conn| conn.worker_info(compact(:worker => worker_name,:worker_key => worker_key)) }
      return_result(result)
    end

    def gen_key options
      key = [options[:worker],options[:worker_key],options[:job_key]].compact.join('_')
      key
    end

    def return_result_from_memcache options = {}
      middle_man.cache[gen_key(options)]
    end

    def return_result result
      result = Array(result)
      result.size <= 1 ? result[0] : result
    end

    def delete
      middle_man.backend_connections.each do |connection|
        connection.delete_worker(compact(:worker => worker_name, :worker_key => worker_key))
      end
      return worker_key
    end

    def choose_connection host_info
      case host_info
      when :all; middle_man.backend_connections
      when :local; middle_man.find_local
      when String; middle_man.find_connection(host_info)
      else; middle_man.choose_server
      end
    end

    def compact(options = { })
      options.delete_if { |key,value| value.nil? }
      options
    end
  end # end of RailsWorkerProxy class

end # end of BackgrounDRb module
