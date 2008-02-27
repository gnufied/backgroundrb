class HelloWorker < BackgrounDRb::MetaWorker
  set_worker_name :hello_worker
  pool_size 10
  
  def create(args = nil)
    # this method is called, when worker is loaded for the first time
    @worker_status = {}
    @status_lock = Mutex.new
    register_status(@worker_status)
  end
  
  def process_status(task_id)
    thread_pool.defer(task_id) do |task_id|
      sleep(2)
      update_status(task_id,"Done man")
    end
    return { :this_should_be => :irrelevant }
  end
  
  def update_status(task_id,status)
    @status_lock.synchronize do 
      @worker_status[task_id] = status
      register_status(@worker_status)
    end
  end
end

