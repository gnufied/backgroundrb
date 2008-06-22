module BackgrounDRb
  class RailsWorkerProxy
    attr_accessor :worker_name, :worker_method, :data, :worker_key,:middle_man

    def self.worker(p_worker_name,p_worker_key = nil,p_middle_man = nil)
      t = new
      t.worker_name = p_worker_name
      t.middle_man = p_middle_man
      t.worker_key = p_worker_key
      t
    end

    def method_missing(method_id,*args)
      worker_method = method_id
      data = args
      case worker_method
      when :ask_result
        middle_man.ask_result(compact(:worker => worker_name,:worker_key => worker_key,:job_key => data[0]))
      when :worker_info
        middle_man.worker_info(compact(:worker => worker_name,:worker_key => worker_key))
      when :delete
        middle_man.delete_worker(compact(:worker => worker_name, :worker_key => worker_key))
      else
        choose_method(worker_method.to_s,data)
      end
    end

    def choose_method worker_method,data
      job_key = data.shift
      if worker_method =~ /^async_(\w+)/
        method_name = $1
        middle_man.ask_work(compact(:worker => worker_name,:worker_key => worker_key,:worker_method => method_name,:job_key => job_key, :arg => data))
      elsif worker_method =~ /^enq_(\w+)/i
        method_name = $1
        args = Marshal.dump([data[0]])
        options = data[1] || {}
        middle_man.enqueue_task(compact(:worker_name => worker_name.to_s,:worker_key => worker_key.to_s,:worker_method => method_name.to_s,:job_key => job_key.to_s, :args => args,:timeout => options[:timeout]))
      else
        middle_man.send_request(compact(:worker => worker_name,:worker_key => worker_key,:worker_method => worker_method,:job_key => job_key,:arg => data))
      end
    end

    def compact(options = { })
      options.delete_if { |key,value| value.nil? }
      options
    end
  end # end of RailsWorkerProxy class

end # end of BackgrounDRb module
