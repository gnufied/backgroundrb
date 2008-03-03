#!/usr/bin/env ruby
module BackgrounDRb
  # Class wraps a logger object for debugging internal errors within server
  class DebugMaster
    attr_accessor :log_mode,:logger,:log_flag
    def initialize(log_mode,log_flag = true)
      @log_mode = log_mode
      @log_flag = log_flag
      if @log_mode == :foreground
        @logger = ::Logger.new(STDOUT)
      else
        @logger = ::Logger.new("#{RAILS_HOME}/log/backgroundrb_#{CONFIG_FILE[:backgroundrb][:port]}_debug.log")
      end
    end

    def info(data)
      return unless @log_flag
      @logger.info(data)
    end

    def debug(data)
      return unless @log_flag
      @logger.debug(data)
    end
  end

  class MasterWorker
    attr_accessor :debug_logger
    def receive_data p_data
      debug_logger.info(p_data)
      @tokenizer.extract(p_data) do |b_data|
        t_data = Marshal.load(b_data)
        debug_logger.info(t_data)
        case t_data[:type]
        when :do_work: process_work(t_data)
        when :get_status: process_status(t_data)
        when :get_result: process_request(t_data)
        when :start_worker: start_worker_request(t_data)
        when :delete_worker: delete_drb_worker(t_data)
        when :all_worker_status: query_all_worker_status(t_data)
        when :worker_info: pass_worker_info(t_data)
        when :all_worker_info: all_worker_info(t_data)
        end
      end
    end

    #
    def pass_worker_info(t_data)
      worker_name_key = gen_worker_key(t_data[:worker],t_data[:job_key])
      worker_instance = reactor.live_workers[worker_name_key]
      info_response = { :worker => t_data[:worker],:job_key => t_data[:job_key]}
      worker_instance ? (info_response[:status] = :running) : (info_response[:status] = :stopped)
      send_object(info_response)
    end

    def all_worker_info(t_data)
      info_response = []
      reactor.live_workers.each do |key,value|
        job_key = (value.worker_key.to_s).gsub(/#{value.worker_name}_?/,"")
        info_response << { :worker => value.worker_name,:job_key => job_key,:status => :running }
      end
      send_object(info_response)
    end

    def query_all_worker_status(p_data)
      dumpable_status = { }
      reactor.live_workers.each { |key,value| dumpable_status[key] = reactor.result_hash[key] }
      send_object(dumpable_status)
    end

    # FIXME: although worker key is removed nonetheless from live_workers hash
    # it could be a good idea to remove it here itself.
    def delete_drb_worker(t_data)
      worker_name = t_data[:worker]
      job_key = t_data[:job_key]
      worker_name_key = gen_worker_key(worker_name,job_key)
      begin
        # ask_worker(worker_name,:job_key => t_data[:job_key],:type => :request, :data => { :worker_method => :exit})
        worker_instance = reactor.live_workers[worker_name_key]
        # pgid = Process.getpgid(worker_instance.pid)
        Process.kill('TERM',worker_instance.pid)
        # Process.kill('-TERM',pgid)

        # Process.kill('KILL',worker_instance.pid)
      rescue Packet::DisconnectError => sock_error
        # reactor.live_workers.delete(worker_name_key)
        reactor.remove_worker(sock_error)
      rescue
        debug_logger.info($!.to_s)
        debug_logger.info($!.backtrace.join("\n"))
      end
    end

    def start_worker_request(p_data)
      start_worker(p_data)
    end

    def process_work(t_data)
      worker_name = t_data[:worker]
      worker_name_key = gen_worker_key(worker_name,t_data[:job_key])
      t_data.delete(:worker)
      t_data.delete(:type)
      begin
        ask_worker(worker_name_key,:data => t_data, :type => :request, :result => false)
      rescue Packet::DisconnectError => sock_error
        reactor.live_workers.delete(worker_name_key)
      rescue
        debug_logger.info($!.to_s)
        debug_logger.info($!.backtrace.join("\n"))
        return
      end

    end

    def process_status(t_data)
      worker_name = t_data[:worker]
      job_key = t_data[:job_key]
      worker_name_key = gen_worker_key(worker_name,job_key)
      status_data = reactor.result_hash[worker_name_key.to_sym]
      send_object(status_data)
    end

    def process_request(t_data)
      worker_name = t_data[:worker]
      worker_name_key = gen_worker_key(worker_name,t_data[:job_key])
      t_data.delete(:worker)
      t_data.delete(:type)
      begin
        ask_worker(worker_name_key,:data => t_data, :type => :request,:result => true)
      rescue Packet::DisconnectError => sock_error
        reactor.live_workers.delete(worker_name_key)
      rescue
        debug_logger.info($!.to_s)
        debug_logger.info($!.backtrace.join("\n"))
        return
      end
    end

    # this method can receive one shot status reports or proper results
    def worker_receive p_data
      send_object(p_data)
    end

    def unbind
      debug_logger.info("Client disconected")
    end
    def post_init
      @tokenizer = BinParser.new
    end
    def connection_completed; end
  end

  class MasterProxy
    attr_accessor :config_file,:reloadable_workers,:worker_triggers,:reactor
    def initialize
      raise "Running old Ruby version, upgrade to Ruby >= 1.8.5" unless check_for_ruby_version
      @config_file = BackgrounDRb::Config.read_config("#{RAILS_HOME}/config/backgroundrb.yml")

      log_flag = CONFIG_FILE[:backgroundrb][:debug_log].nil? ? true : CONFIG_FILE[:backgroundrb][:debug_log]
      debug_logger = DebugMaster.new(CONFIG_FILE[:backgroundrb][:log],log_flag)

      load_rails_env

      find_reloadable_worker

      Packet::Reactor.run do |t_reactor|
        @reactor = t_reactor
        enable_memcache_result_hash(t_reactor) if CONFIG_FILE[:backgroundrb][:result_storage] && CONFIG_FILE[:backgroundrb][:result_storage][:memcache]
        t_reactor.start_worker(:worker => :log_worker) if log_flag
        t_reactor.start_server(CONFIG_FILE[:backgroundrb][:ip],CONFIG_FILE[:backgroundrb][:port],MasterWorker) { |conn|  conn.debug_logger = debug_logger }
        t_reactor.next_turn { reload_workers }
      end
    end

    def gen_worker_key(worker_name,job_key = nil)
      return worker_name if job_key.nil?
      return "#{worker_name}_#{job_key}".to_sym
    end


    # method should find reloadable workers and load their schedule from config file
    def find_reloadable_worker
      t_workers = Dir["#{WORKER_ROOT}/**/*.rb"]
      @reloadable_workers = t_workers.map do |x|
        worker_name = File.basename(x,".rb")
        require worker_name
        worker_klass = Object.const_get(worker_name.classify)
        worker_klass.reload_flag ? worker_klass : nil
      end.compact
      @worker_triggers = { }
      @reloadable_workers.each do |t_worker|
        schedule = load_reloadable_schedule(t_worker)
        if schedule && !schedule.empty?
          @worker_triggers[t_worker.worker_name.to_sym] = schedule
        end
      end
    end

    def load_reloadable_schedule(t_worker)
      worker_method_triggers = { }
      worker_schedule = CONFIG_FILE[:schedules][t_worker.worker_name.to_sym]

      worker_schedule && worker_schedule.each do |key,value|
        case value[:trigger_args]
        when String
          cron_args = value[:trigger_args] || "0 0 0 0 0"
          trigger = BackgrounDRb::CronTrigger.new(cron_args)
        when Hash
          trigger = BackgrounDRb::Trigger.new(value[:trigger_args])
        end
        worker_method_triggers[key] = { :trigger => trigger,:data => value[:data],:runtime => trigger.fire_after_time(Time.now).to_i }
      end
      worker_method_triggers
    end

    # method will reload workers that should be loaded on each schedule
    def reload_workers
      return if worker_triggers.empty?
      worker_triggers.each do |key,value|
        value.delete_if { |key,value| value[:trigger].respond_to?(:end_time) && value[:trigger].end_time <= Time.now }
      end

      worker_triggers.each do |worker_name,trigger|
        trigger.each do |key,value|
          time_now = Time.now.to_i
          if value[:runtime] < time_now
            load_and_invoke(worker_name,key,value)
            t_time = value[:trigger].fire_after_time(Time.now)
            value[:runtime] = t_time.to_i
          end
        end
      end
    end

    # method will load the worker and invoke worker method
    def load_and_invoke(worker_name,p_method,data)
      begin
        require worker_name.to_s
        job_key = Packet::Guid.hexdigest
        @reactor.start_worker(:worker => worker_name,:job_key => job_key)
        worker_name_key = gen_worker_key(worker_name,job_key)
        data_request = {:data => { :worker_method => p_method,:data => data[:data]},
          :type => :request, :result => false
        }

        exit_request = {:data => { :worker_method => :exit},
          :type => :request, :result => false
        }

        @reactor.live_workers[worker_name_key].send_request(data_request)
        @reactor.live_workers[worker_name_key].send_request(exit_request)
      rescue LoadError
        puts "no such worker #{worker_name}"
      rescue MissingSourceFile
        puts "no such worker #{worker_name}"
        return
      end
    end

    def load_rails_env
      db_config_file = YAML.load(ERB.new(IO.read("#{RAILS_HOME}/config/database.yml")).result)
      run_env = CONFIG_FILE[:backgroundrb][:environment] || 'development'
      ENV["RAILS_ENV"] = run_env
      RAILS_ENV.replace(run_env) if defined?(RAILS_ENV)
      require RAILS_HOME + '/config/environment.rb'
      lazy_load = CONFIG_FILE[:backgroundrb][:lazy_load].nil? ? true : CONFIG_FILE[:backgroundrb][:lazy_load].nil?
      p lazy_load
      load_rails_models unless lazy_load
      ActiveRecord::Base.allow_concurrency = true
    end

    def load_rails_models
      model_root = RAILS_HOME + "/app/models"
      models = Dir["#{model_root}/**/*.rb"]
      models.each { |x|
        begin
          require x
        rescue LoadError
          next
        rescue MissingSourceFile
          next
        end
      }
    end

    def enable_memcache_result_hash(t_reactor)
      require 'memcache'
      memcache_options = {
        :c_threshold => 10_000,
        :compression => true,
        :debug => false,
        :namespace => 'backgroundrb_result_hash',
        :readonly => false,
        :urlencode => false
      }
      cache = MemCache.new(memcache_options)
      cache.servers = CONFIG_FILE[:backgroundrb][:result_storage][:memcache].split(',')
      t_reactor.set_result_hash(cache)
    end

    def check_for_ruby_version; return RUBY_VERSION >= "1.8.5"; end

  end # end of module BackgrounDRb
end



