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
      worker_method = method_id
      arguments = *args

      result = nil

      connection = (Hash === arguments ) ? middle_man.choose_server(arguments[:host]) : middle_man.choose_server
      @tried_connections << connection.server_info

      begin
        result = invoke_on_connection(connection,worker_method,data)
      rescue BdrbConnError => e
        connection = middle_man.find_next_except_these(@tried_connections)
        @tried_connections << connection.server_info
        retry
      end
    end

    def invoke_on_connection connection,worker_method,data
      raise NoServerAvailable.new("No BackgrounDRb server is found running") unless connection
      case worker_method
      when :ask_result
        connection.ask_result(compact(:worker => worker_name,:worker_key => worker_key,:job_key => data[0]))
      when :worker_info
        connection.worker_info(compact(:worker => worker_name,:worker_key => worker_key))
      when :delete
        connection.delete_worker(compact(:worker => worker_name, :worker_key => worker_key))
      else
        choose_method(worker_method.to_s,data,connection)
      end
    end

    def choose_method worker_method,data,connection
      job_key = data[0]
      if worker_method =~ /^async_(\w+)/
        method_name = $1
        connection.ask_work(compact(:worker => worker_name,:worker_key => worker_key,:worker_method => method_name,:job_key => job_key, :arg => data[1..-1]))
      elsif worker_method =~ /^enq_(\w+)/i
        method_name = $1
        args = Marshal.dump([data[1]])
        options = data[2] || {}
        connection.enqueue_task(compact(:worker_name => worker_name.to_s,:worker_key => worker_key.to_s,:worker_method => method_name.to_s,:job_key => job_key.to_s, :args => args,:timeout => options[:timeout]))
      else
        connection.send_request(compact(:worker => worker_name,:worker_key => worker_key,:worker_method => worker_method,:job_key => job_key,:arg => data[1..-1]))
      end
    end

    def compact(options = { })
      options.delete_if { |key,value| value.nil? }
      options
    end
  end # end of RailsWorkerProxy class

end # end of BackgrounDRb module
