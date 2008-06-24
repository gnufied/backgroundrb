module BackgrounDRb
  class WorkData
    attr_accessor :data,:block
    def initialize(args,job_key,&block)
      @data = args
      @job_key = job_key
      @block = block
    end
  end

  class ParallelData
    attr_accessor :data,:block,:response_block,:job_key
    def initialize(args,job_key,block,response_block)
      @data = args
      @block = block
      @response_block = response_block
      @job_key = job_key
    end
  end

  class ResultData
    attr_accessor :data,:block,:job_key
    def initialize args,job_key,&block
      @data = args
      @block = block
      @job_key = job_key
    end
  end

  class ThreadPool
    attr_accessor :size,:threads,:work_queue,:logger
    attr_accessor :result_queue
    def initialize(size,logger)
      @logger = logger
      @size = size
      @threads = []
      @work_queue = Queue.new
      @running_tasks = Queue.new
      @result_queue = Queue.new
      @size.times { add_thread }
    end

    # can be used to make a call in threaded manner
    # passed block runs in a thread from thread pool
    # for example in a worker method you can do:
    #   def fetch_url(url)
    #     puts "fetching url #{url}"
    #     thread_pool.defer(url) do |url|
    #       begin
    #         data = Net::HTTP.get(url,'/')
    #         File.open("#{RAILS_ROOT}/log/pages.txt","w") do |fl|
    #           fl.puts(data)
    #         end
    #       rescue
    #         logger.info "Error downloading page"
    #       end
    #     end
    #   end
    # you can invoke above method from rails as:
    #   MiddleMan.ask_work(:worker => :rss_worker, :worker_method => :fetch_url, :data => "www.example.com")
    # assuming method is defined in rss_worker

    def defer(*args,&block)
      job_key = Thread.current[:job_key]
      @work_queue << WorkData.new(args,job_key,&block)
    end

    # Same as defer, but can be used to run a block in a seperate thread and collect results back
    # in main thread
    def run_concurrent(args,process_block,response_block)
      job_key = Thread.current[:job_key]
      @work_queue << ParallelData.new(args,job_key,process_block,response_block)
    end

    def add_thread
      @threads << Thread.new do
        Thread.current[:job_key] = nil
        while true
          task = @work_queue.pop
          Thread.current[:job_key] = task.job_key
          @running_tasks << task
          block_result = run_task(task)
          @running_tasks.pop
        end
      end
    end

    def result_empty?
      return true if @result_queue.empty?
      return false
    end

    def result_pop
      @result_queue.pop
    end

    def run_task task
      block_arity = task.block.arity
      begin
        ActiveRecord::Base.verify_active_connections!
        t_data = task.data
        result = nil
        if block_arity != 0
          result = t_data.is_a?(Array) ? (task.block.call(*t_data)) : (task.block.call(t_data))
        else
          result = task.block.call
        end
        return result
      rescue
        logger.info($!.to_s)
        logger.info($!.backtrace.join("\n"))
        return nil
      end
    end

    # method ensures exclusive run of deferred tasks for 2 seconds, so as they do get a chance to run.
    def exclusive_run
      if @running_tasks.empty? && @work_queue.empty?
        return
      else
        sleep(0.05)
        return
      end
    end
  end
end
