# class implements general worker
module Packet
  class Worker
    include Core
    iattr_accessor :fd_reader,:msg_writer,:msg_reader,:worker_name
    iattr_accessor :worker_proxy
    iattr_accessor :no_auto_load

    attr_accessor :worker_started, :worker_options
    after_connection :provide_workers

    # method initializes the eventloop for the worker
    def self.start_worker(messengers = {})
      @msg_writer = messengers[:write_end]
      @msg_reader = messengers[:read_end]
      t_instance = new
      t_instance.worker_options = messengers[:options]
      t_instance.worker_init if t_instance.respond_to?(:worker_init)
      t_instance.start_reactor
      t_instance
    end

    def initialize
      super
      @read_ios << msg_reader
      # @read_ios << fd_reader
      @tokenizer = BinParser.new
    end

    def send_data p_data
      dump_object(p_data,msg_writer)
    end

    def send_request(options = {})
      t_data = options[:data]
      if t_callback = options[:callback]
        callback_hash[t_callback.signature] = t_callback
        send_data(:data => t_data,:function => options[:function],:callback_signature => t_callback.signature)
      else
        send_data(:data => t_data,:function => options[:function],:requested_worker => options[:worker],:requesting_worker => worker_name,:type => :request)
      end
    end

    # method handles internal requests from internal sockets
    def handle_internal_messages(t_sock)
      t_data = read_data(t_sock)
      receive_internal_data(t_data)
    end

    def receive_internal_data data
      @tokenizer.extract(data) do |b_data|
        data_obj = Marshal.load(b_data)
        receive_data(data_obj)
      end
    end

    # FIXME: this method is being duplicated between packet and worker classes, may be its a
    # good idea to merge them.
    def provide_workers(handler_instance,connection)
      class << handler_instance
        extend Forwardable
        attr_accessor :worker, :connection, :reactor, :initialized, :signature
        include NbioHelper
        include Connection
        def_delegators :@reactor, :start_server, :connect, :add_periodic_timer, :add_timer, :cancel_timer,:reconnect
      end
      handler_instance.connection = connection
      handler_instance.worker = self
      handler_instance.reactor = self
    end

    def log log_data
      send_data(:requested_worker => :log_worker,:data => log_data,:type => :request)
    end

    # method receives data from external TCP Sockets
    def receive_data p_data
      raise "Not implemented for worker"
    end

    # method checks if client has asked to execute a internal function
    def invoke_internal_function
      raise "Not implemented for worker"
    end

    # message returns data to parent process, using UNIX Sockets
    def invoke_callback
      raise "Not implemented for worker"
    end

  end # end of class#Worker
end

