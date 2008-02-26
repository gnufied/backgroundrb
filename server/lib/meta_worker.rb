module BackgrounDRb
  # this class is a dummy class that implements things required for passing data to
  # actual logger worker
  class PacketLogger
    def initialize(worker,log_flag = true)
      @log_flag = log_flag
      @worker = worker
    end
    def info(p_data)
      return unless @log_flag
      @worker.send_request(:worker => :log_worker, :data => p_data)
    end

    def debug(p_data)
      return unless @log_flag
      @worker.send_request(:worker => :log_worker, :data => p_data)
    end

    def error(p_data)
      return unless @log_flag
      @worker.send_request(:worker => :log_worker, :data => p_data)
    end
  end

  class WorkData
    attr_accessor :data,:block
    def initialize(args,&block)
      @data = args
      @block = block
    end
  end

  class ThreadPool
    attr_accessor :size,:threads,:work_queue,:logger
    def initialize(size,logger)
      @logger = logger
      @size = size
      @threads = []
      @work_queue = Queue.new
      @running_tasks = Queue.new
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

    def add_thread
      @threads << Thread.new do
        while true
          task = @work_queue.pop
          @running_tasks << task
          block_arity = task.block.arity

          begin
            ActiveRecord::Base.verify_active_connections!
            block_arity == 0 ? task.block.call : task.block.call(*(task.data))
          rescue
            logger.info($!.to_s)
            logger.info($!.backtrace.join("\n"))
          end
          @running_tasks.pop
        end
      end
    end

    # method ensures exclusive run of deferred tasks for 2 seconds, so as they do get a chance to run.
    def exclusive_run
      if @running_tasks.empty? && @work_queue.empty?
        return
      else
        # puts "going to sleep for a while"
        sleep(0.05)
        return
      end
    end
  end

  # == MetaWorker class
  # BackgrounDRb workers are asynchrounous reactors which work using events
  # You are free to use threads in your workers, but be reasonable with them.
  # Following methods are available to all workers from parent classes.
  # * BackgrounDRb::MetaWorker#connect
  #
  #   Above method connects to an external tcp server and integrates the connection
  #   within reactor loop of worker. For example:
  #
  #        class TimeClient
  #          def receive_data(p_data)
  #            worker.get_external_data(p_data)
  #          end
  #
  #          def post_init
  #            p "***************** : connection completed"
  #          end
  #        end
  #
  #        class FooWorker < BackgrounDRb::MetaWorker
  #          set_worker_name :foo_worker
  #          def create(args = nil)
  #            external_connection = nil
  #            connect("localhost",11009,TimeClient) { |conn| external_connection = conn }
  #          end
  #
  #          def get_external_data(p_data)
  #            puts "And external data is : #{p_data}"
  #          end
  #        end
  # * BackgrounDRb::MetaWorker#start_server
  #
  #   Above method allows you to start a tcp server from your worker, all the
  #   accepted connections are integrated with event loop of worker
  #      class TimeServer
  #
  #        def receive_data(p_data)
  #        end
  #
  #        def post_init
  #          add_periodic_timer(2) { say_hello_world }
  #        end
  #
  #        def connection_completed
  #        end
  #
  #        def say_hello_world
  #          p "***************** : invoking hello world #{Time.now}"
  #          send_data("Hello World\n")
  #        end
  #      end
  #
  #      class ServerWorker < BackgrounDRb::MetaWorker
  #        set_worker_name :server_worker
  #        def create(args = nil)
  #          # start the server when worker starts
  #          start_server("0.0.0.0",11009,TimeServer) do |client_connection|
  #            client_connection.say_hello_world
  #          end
  #        end
  #      end

  class MetaWorker < Packet::Worker
    attr_accessor :config_file, :my_schedule, :run_time, :trigger_type, :trigger
    attr_accessor :logger, :thread_pool
    iattr_accessor :pool_size
    iattr_accessor :reload_flag
    
    @pool_size = nil
    @reload_flag = false
    
    def self.pool_size(size = nil)
      @pool_size = size if size
      @pool_size
    end
    
    def self.reload_on_schedule(flag = nil)
      if flag
        self.no_auto_load = true 
        self.reload_flag = true
      end
    end

    # does initialization of worker stuff and invokes create method in
    # user defined worker class
    def worker_init
      @config_file = BackgrounDRb::Config.read_config("#{RAILS_HOME}/config/backgroundrb.yml")
      log_flag = @config_file[:backgroundrb][:debug_log].nil? ? true : @config_file[:backgroundrb][:debug_log]
      load_rails_env
      @logger = PacketLogger.new(self,log_flag)
      @thread_pool = ThreadPool.new(pool_size || 20,@logger)

      if(worker_options && worker_options[:schedule] && no_auto_load)
        load_schedule_from_args
      elsif(@config_file[:schedules] && @config_file[:schedules][worker_name.to_sym])
        @my_schedule = @config_file[:schedules][worker_name.to_sym]
        new_load_schedule if @my_schedule
      end
      if respond_to?(:create)
        create_arity = method(:create).arity
        (create_arity == 0) ? create : create(worker_options[:data])
      end
      @logger.info "#{worker_name} started"
      @logger.info "Schedules for worker loaded"
    end

    # loads workers schedule from options supplied from rails
    # a user may pass trigger arguments to dynamically define the schedule
    def load_schedule_from_args
      @my_schedule = worker_options[:schedule]
      new_load_schedule if @my_schedule
    end

    # receives requests/responses from master process or other workers
    def receive_data p_data
      if p_data[:data][:worker_method] == :exit
        exit
        return
      end
      case p_data[:type]
      when :request: process_request(p_data)
      when :response: process_response(p_data)
      end
    end

    # method is responsible for invoking appropriate method in user
    def process_request(p_data)
      user_input = p_data[:data]
      logger.info "#{user_input[:worker_method]} #{user_input[:data]}"
      if (user_input[:worker_method]).nil? or !respond_to?(user_input[:worker_method])
        logger.info "Undefined method #{user_input[:worker_method]} called on worker #{worker_name}"
        return
      end
      called_method_arity = self.method(user_input[:worker_method]).arity
      result = nil
      if called_method_arity != 0
        result = self.send(user_input[:worker_method],user_input[:data])
      else
        result = self.send(user_input[:worker_method])
      end
      if p_data[:result]
        result = "dummy_result" unless result
        send_response(p_data,result) if can_dump?(result)
      end
    end

    def can_dump?(p_object)
      begin
        Marshal.dump(p_object)
        return true
      rescue TypeError
        return false
      rescue
        return false
      end
    end

    # new experimental scheduler
    def new_load_schedule
      @worker_method_triggers = { }
      @my_schedule.each do |key,value|
        case value[:trigger_args]
        when String
          cron_args = value[:trigger_args] || "0 0 0 0 0"
          trigger = BackgrounDRb::CronTrigger.new(cron_args)
        when Hash
          trigger = BackgrounDRb::Trigger.new(value[:trigger_args])
        end
        @worker_method_triggers[key] = { :trigger => trigger,:data => value[:data],:runtime => trigger.fire_after_time(Time.now).to_i }
      end
    end

    # probably this method should be made thread safe, so as a method needs to have a
    # lock or something before it can use the method
    def register_status p_data
      status = {:type => :status,:data => p_data}
      begin
        send_data(status)
      rescue TypeError => e
        status = {:type => :status,:data => "invalid_status_dump_check_log"}
        send_data(status)
        logger.info(e.to_s)
        logger.info(e.backtrace.join("\n"))
      rescue
        status = {:type => :status,:data => "invalid_status_dump_check_log"}
        send_data(status)
        logger.info($!.to_s)
        logger.info($!.backtrace.join("\n"))
      end
    end

    def send_response input,output
      input[:data] = output
      input[:type] = :response
      
      begin
        send_data(input)
      rescue TypeError => e
        logger.info(e.to_s)
        logger.info(e.backtrace.join("\n"))
        input[:data] = "invalid_result_dump_check_log"
        send_data(input)
      rescue
        logger.info($!.to_s)
        logger.info($!.backtrace.join("\n"))
        input[:data] = "invalid_result_dump_check_log"
        send_data(input)
      end
    end

    def unbind; end

    def connection_completed; end

    def check_for_timer_events
      begin
        ActiveRecord::Base.verify_active_connections! if defined?(ActiveRecord)
        super
      rescue
        logger.info($!.to_s)
        logger.info($!.backtrace.join("\n"))
      end

      return if @worker_method_triggers.nil? or @worker_method_triggers.empty?
      @worker_method_triggers.delete_if { |key,value| value[:trigger].respond_to?(:end_time) && value[:trigger].end_time <= Time.now }
      
      @worker_method_triggers.each do |key,value|
        time_now = Time.now.to_i
        if value[:runtime] < time_now
          begin
            (t_data = value[:data]) ? send(key,t_data) : send(key)
          rescue
            # logger.info($!.to_s)
            # logger.info($!.backtrace.join("\n"))
            puts $!
            puts $!.backtrace
          end
          t_time = value[:trigger].fire_after_time(Time.now)
          value[:runtime] = t_time.to_i
        end
      end
    end

    # method would allow user threads to run exclusively for a while
    def run_user_threads
      @thread_pool.exclusive_run
    end
    
    private
    def load_rails_env
      db_config_file = YAML.load(ERB.new(IO.read("#{RAILS_HOME}/config/database.yml")).result)
      run_env = @config_file[:backgroundrb][:environment] || 'development'
      ENV["RAILS_ENV"] = run_env
      RAILS_ENV.replace(run_env) if defined?(RAILS_ENV)
      ActiveRecord::Base.establish_connection(db_config_file[run_env])
      ActiveRecord::Base.allow_concurrency = true
    end

  end # end of class MetaWorker
end # end of module BackgrounDRb
