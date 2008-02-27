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
      
    end
  end
end
