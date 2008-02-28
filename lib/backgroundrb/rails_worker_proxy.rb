module BackgrounDRb
  class RailsWorkerProxy
    attr_accessor :worker_name, :worker_method, :data, :job_key 
    def self.worker(p_worker_name,p_job_key = nil)
      t = new
      t.worker_name = p_worker_name
      t.job_key = p_job_key
      t
    end
    
    def method_missing(method_id,*args)
      worker_method = method_id
      data = args[0]
      flag = args[1]
      case worker_method
      when :ask_status
        MiddleMan.ask_status(compact(:worker => worker_name,:job_key => job_key))
      when :worker_info
        MiddleMan.worker_info(compact(:worker => worker_name,:job_key => job_key))
      when :delete
        MiddleMan.delete_worker(compact(:worker => worker_name, :job_key => job_key))
      else
        if flag
          MiddleMan.send_request(compact(:worker => worker_name,:job_key => job_key,:worker_method => worker_method,:data => data))
        else
          MiddleMan.ask_work(compact(:worker => worker_name,:job_key => job_key,:worker_method => worker_method,:data => data))
        end
      end
    end
    
    def compact(options = { })
      options.delete_if { |key,value| value.nil? }
      options
    end

    
  end # end of RailsWorkerProxy class
  
end # end of BackgrounDRb module
