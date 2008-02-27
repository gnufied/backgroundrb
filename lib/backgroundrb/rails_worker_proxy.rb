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
      @worker_method = method_id
      @data = args[0]
      flag = args[1]
      case @worker_method
      when :ask_status
        if job_key 
          MiddleMan.ask_status(:worker => worker_name,:job_key => job_key)
        else
          MiddleMan.ask_status(:worker => worker_name)
        end
      when :worker_info
    
      when :all_worker_info
        
      when :new_worker
        
      when :delete
        
      else
        
        
      end
    end
    
    def pack_modifers(p_option = { })
    end

    
  end # end of RailsWorkerProxy class
  
end # end of BackgrounDRb module
