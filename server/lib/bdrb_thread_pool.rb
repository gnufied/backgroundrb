module BackgrounDRb
  class WorkData
    attr_accessor :data,:block
    def initialize(args,&block)
      @data = args
      @block = block
    end
  end

  class ParallelData
    attr_accessor :data,:block,:response_block,:guid
    def initialize(args,block,response_block)
      @data = args
      @block = block
      @response_block = response_block
      @guid = Packet::Guid.hexdigest
    end
  end

  class ResultData
    attr_accessor :data,:block
    def initialize args,&block
      @data = args
      @block = block
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
      @work_queue << WorkData.new(args,&block)
    end

    # Same as defer, but can be used to run a block in a seperate thread and collect results back
    # in main thread
    def fetch_parallely(args,process_block,response_block)
      @work_queue << ParallelData.new(args,process_block,response_block)
    end

    def add_thread
      @threads << Thread.new do
        while true
          task = @work_queue.pop
          @running_tasks << task
          block_result = run_task(task)
          if task.is_a? ParallelData
            @result_queue << ResultData.new(block_result,&task.response_block)
          end
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
        data = (task.data.is_a?(Array)) ? *(task.data) : task.data
        result = (block_arity == 0 ? task.block.call : task.block.call(data))
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
