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
  #            connect("localhost",11009,TimeClient) { |conn| conn = external_connection }
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
    include BackgrounDRb::BdrbServerHelper
    attr_accessor :config_file, :my_schedule, :run_time, :trigger_type, :trigger
    attr_accessor :logger, :thread_pool,:cache
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
      log_flag = @config_file[:backgroundrb][:debug_log].nil? ? true : @config_file[:backgroundrb][:debug_load_rails_env]

      # stores the job key of currently running job
      Thread.current[:job_key] = nil
      @logger = PacketLogger.new(self,log_flag)
      @thread_pool = ThreadPool.new(self,pool_size || 20,@logger)
      @cache = ResultStorage.new(worker_name,worker_options[:worker_key],BDRB_CONFIG[:backgroundrb][:result_storage])

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
      add_periodic_timer(1) { check_for_enqueued_tasks }
    end

    def job_key; Thread.current[:job_key]; end
    def worker_key; worker_options[:worker_key]; end

    # loads workers schedule from options supplied from rails
    # a user may pass trigger arguments to dynamically define the schedule
    def load_schedule_from_args
      @my_schedule = worker_options[:schedule]
      new_load_schedule if @my_schedule
    end

    def receive_internal_data data
      @tokenizer.extract(data) do |b_data|
        data_obj = load_data(b_data)
        receive_data(data_obj) if data_obj
      end
    end

    # receives requests/responses from master process or other workers
    def receive_data p_data
      if p_data[:data][:worker_method] == :exit
        exit
      end
      case p_data[:type]
      when :request: process_request(p_data)
      when :response: process_response(p_data)
      when :get_result: return_result_object(p_data)
      end
    end

    def return_result_object p_data
      user_input = p_data[:data]
      user_job_key = user_input[:job_key]
      send_response(p_data,cache[user_job_key])
    end

    # method is responsible for invoking appropriate method in user
    def process_request(p_data)
      user_input = p_data[:data]
      if (user_input[:worker_method]).nil? or !respond_to?(user_input[:worker_method])
        result = nil
        send_response(p_data,result)
        return
      end

      called_method_arity = self.method(user_input[:worker_method]).arity
      result = nil

      Thread.current[:job_key] = user_input[:job_key]

      if called_method_arity != 0
        result = self.send(user_input[:worker_method],*user_input[:arg])
      else
        result = self.send(user_input[:worker_method])
      end

      if p_data[:result]
        result = "dummy_result" if result.nil?
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
          @worker_method_triggers[key] = { :trigger => trigger,:data => value[:data],:runtime => trigger.fire_after_time(Time.now).to_i }
        when Hash
          trigger = BackgrounDRb::Trigger.new(value[:trigger_args])
          @worker_method_triggers[key] = { :trigger => trigger,:data => value[:trigger_args][:data],:runtime => trigger.fire_after_time(Time.now).to_i }
        end
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

    def check_for_enqueued_tasks
      if worker_key && !worker_key.empty?
        task = BdrbJobQueue.find_next(worker_name.to_s,worker_key.to_s)
      else
        task = BdrbJobQueue.find_next(worker_name.to_s)
      end
      return unless task
      if self.respond_to? task.worker_method
        called_method_arity = self.method(task.worker_method).arity
        args = load_data(task.args)
        if called_method_arity != 0
          self.send(task.worker_method,*args)
        else
          self.send(task.worker_method)
        end
      else
        task.release_job
      end
    end

    def check_for_timer_events
      super
      return if @worker_method_triggers.nil? or @worker_method_triggers.empty?
      @worker_method_triggers.delete_if { |key,value| value[:trigger].respond_to?(:end_time) && value[:trigger].end_time <= Time.now }

      @worker_method_triggers.each do |key,value|
        time_now = Time.now.to_i
        if value[:runtime] < time_now
          check_db_connection
          begin
            (t_data = value[:data]) ? send(key,t_data) : send(key)
          rescue
            logger.info($!.to_s)
            logger.info($!.backtrace.join("\n"))
          end
          t_time = value[:trigger].fire_after_time(Time.now)
          value[:runtime] = t_time.to_i
        end
      end
    end

    def check_db_connection
      begin
        ActiveRecord::Base.verify_active_connections! if defined?(ActiveRecord)
      rescue
        logger.info($!.to_s)
        logger.info($!.backtrace.join("\n"))
      end
    end

    # method would allow user threads to run exclusively for a while
    def run_user_threads
      @thread_pool.exclusive_run
    end

    private
    def load_rails_env
      db_config_file = YAML.load(ERB.new(IO.read("#{RAILS_HOME}/config/database.yml")).result)
      run_env = ENV["RAILS_ENV"]
      ActiveRecord::Base.establish_connection(db_config_file[run_env])
      ActiveRecord::Base.allow_concurrency = true
    end

  end # end of class MetaWorker
end # end of module BackgrounDRb
