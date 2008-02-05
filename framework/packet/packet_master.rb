module Packet
  class Reactor
    include Core
    attr_accessor :fd_writers, :msg_writers,:msg_reader
    attr_accessor :result_hash

    attr_accessor :live_workers
    after_connection :provide_workers

    def self.server_logger= (log_file_name)
      @@server_logger = log_file_name
    end

    def self.run
      master_reactor_instance = new
      master_reactor_instance.result_hash = {}
      master_reactor_instance.live_workers = DoubleKeyedHash.new
      yield(master_reactor_instance)
      master_reactor_instance.load_workers
      master_reactor_instance.start_reactor
    end # end of run method

    def set_result_hash(hash)
      @result_hash = hash
    end

    def update_result(worker_key,result)
      @result_hash ||= {}
      @result_hash[worker_key.to_sym] = result
    end

    def provide_workers(handler_instance,t_sock)
      class << handler_instance
        extend Forwardable
        attr_accessor :workers,:connection,:reactor, :initialized,:signature
        include NbioHelper
        include Connection
        def ask_worker(*args)
          worker_name = args.shift
          data_options = *args
          worker_name_key = gen_worker_key(worker_name,data_options[:job_key])
          data_options[:client_signature] = connection.fileno
          reactor.live_workers[worker_name_key].send_request(data_options)
        end

        def_delegators(:@reactor, :start_server, :connect, :add_periodic_timer, \
                         :add_timer, :cancel_timer,:reconnect, :start_worker,:delete_worker)

      end
      handler_instance.workers = @live_workers
      handler_instance.connection = t_sock
      handler_instance.reactor = self
    end

    # FIXME: right now, each worker is tied to its connection and this can be problematic
    # what if a worker wants to return results in a async manner
    def handle_internal_messages(t_sock)
      sock_fd = t_sock.fileno
      worker_instance = @live_workers[sock_fd]
      begin
        raw_data = read_data(t_sock)
        # t_data = Marshal.load(raw_data)
        worker_instance.receive_data(raw_data) if worker_instance.respond_to?(:receive_data)
      rescue DisconnectError => sock_error
        remove_worker(t_sock)
      end
    end

    def remove_worker(t_sock)
      @live_workers.delete(t_sock.fileno)
      read_ios.delete(t_sock)
    end

    def delete_worker(worker_options = {})
      worker_name = worker_options[:worker]
      worker_name_key = gen_worker_key(worker_name,worker_options[:job_key])
      worker_options[:method] = :exit
      @live_workers[worker_name_key].send_request(worker_options)
    end

    # method loads workers in new processes
    # FIXME: this method can be fixed, so as worker code can be actually, required
    # only in forked process and hence saving upon the memory involved
    # where worker is actually required in master as well as in worker.
    def load_workers
      if defined?(WORKER_ROOT)
        worker_root = WORKER_ROOT
      else
        worker_root = "#{PACKET_APP}/worker"
      end
      t_workers = Dir["#{worker_root}/**/*.rb"]
      return if t_workers.empty?
      t_workers.each do |b_worker|
        worker_name = File.basename(b_worker,".rb")
        require worker_name
        worker_klass = Object.const_get(packet_classify(worker_name))
        next if worker_klass.no_auto_load
        fork_and_load(worker_klass)
      end

      # FIXME: easiest and yet perhaps a bit ugly, its just to make sure that from each
      # worker proxy one can access other workers
      @live_workers.each do |key,worker_instance|
        worker_instance.workers = @live_workers
      end
    end

    def start_worker(worker_options = { })
      worker_name = worker_options[:worker].to_s
      worker_name_key = gen_worker_key(worker_name,worker_options[:job_key])
      return if @live_workers[worker_name_key]
      worker_options.delete(:worker)
      begin
        require worker_name
        worker_klass = Object.const_get(packet_classify(worker_name))
        fork_and_load(worker_klass,worker_options)
      rescue MissingSourceFile
        puts "no such worker #{worker_name}"
        return
      end
    end

    # method forks given worker file in a new process
    # method should use job_key if provided in options hash.
    def fork_and_load(worker_klass,worker_options = { })
      t_worker_name = worker_klass.worker_name
      worker_pimp = worker_klass.worker_proxy.to_s

      # socket from which master process is going to read
      master_read_end,worker_write_end = UNIXSocket.pair(Socket::SOCK_STREAM)
      # socket to which master process is going to write
      worker_read_end,master_write_end = UNIXSocket.pair(Socket::SOCK_STREAM)
      #worker_read_fd,master_write_fd = UNIXSocket.pair

      if((pid = fork()).nil?)
        $0 = "ruby #{worker_klass.worker_name}"
        [master_write_end,master_read_end].each { |x| x.close }

        worker_klass.start_worker(:write_end => worker_write_end,:read_end => worker_read_end,\
                                  :options => worker_options)
      end
      Process.detach(pid)

      worker_name_key = gen_worker_key(t_worker_name,worker_options[:job_key])

      if worker_pimp && !worker_pimp.empty?
        require worker_pimp
        pimp_klass = Object.const_get(packet_classify(worker_pimp))
        @live_workers[worker_name_key,master_read_end.fileno] = pimp_klass.new(master_write_end,pid,self)
      else
        t_pimp = Packet::MetaPimp.new(master_write_end,pid,self)
        t_pimp.worker_key = worker_name_key
        t_pimp.worker_name = t_worker_name
        @live_workers[worker_name_key,master_read_end.fileno] = t_pimp
      end

      worker_read_end.close
      worker_write_end.close
      #worker_read_fd.close
      read_ios << master_read_end
    end # end of fork_and_load method
  end # end of Reactor class
end # end of Packet module
