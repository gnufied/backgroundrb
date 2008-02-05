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
        @logger = ::Logger.new("#{RAILS_HOME}/log/backgroundrb_debug.log")
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
        Process.kill('KILL',worker_instance.pid)
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
        ask_worker(worker_name_key,:data => t_data, :type => :request)
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
        ask_worker(worker_name_key,:data => t_data, :type => :request)
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
    attr_accessor :config_file
    def initialize
      raise "Running old Ruby version, upgrade to Ruby >= 1.8.5" unless check_for_ruby_version
      @config_file = YAML.load(ERB.new(IO.read("#{RAILS_HOME}/config/backgroundrb.yml")).result)
      log_flag = @config_file[:backgroundrb][:debug_log].nil? ? true : @config_file[:backgroundrb][:debug_log]
      debug_logger = DebugMaster.new(@config_file[:backgroundrb][:log],log_flag)

      load_rails_env
      Packet::Reactor.run do |t_reactor|
        enable_memcache_result_hash(t_reactor) if @config_file[:backgroundrb][:result_storage] && @config_file[:backgroundrb][:result_storage][:memcache]
        t_reactor.start_worker(:worker => :log_worker)
        t_reactor.start_server(@config_file[:backgroundrb][:ip],@config_file[:backgroundrb][:port],MasterWorker) { |conn|  conn.debug_logger = debug_logger }
      end
    end

    def load_rails_env
      db_config_file = YAML.load(ERB.new(IO.read("#{RAILS_HOME}/config/database.yml")).result)
      run_env = @config_file[:backgroundrb][:environment] || 'development'
      ENV["RAILS_ENV"] = run_env
      RAILS_ENV.replace(run_env) if defined?(RAILS_ENV)
      require RAILS_HOME + '/config/environment.rb'
      load_rails_models unless @config_file[:backgroundrb][:lazy_load]
      ActiveRecord::Base.allow_concurrency = true
    end

    def load_rails_models
      model_root = RAILS_HOME + "/app/models"
      models = Dir["#{model_root}/**/*.rb"]
      models.each { |x|
        begin
          require x
        rescue
          p $!
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
      cache.servers = @config_file[:backgroundrb][:result_storage][:memcache].split(',')
      t_reactor.set_result_hash(cache)
    end

    def check_for_ruby_version; return RUBY_VERSION >= "1.8.5"; end

  end # end of module BackgrounDRb
end



