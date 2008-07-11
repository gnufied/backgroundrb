require File.join(File.dirname(__FILE__) + "/..","bdrb_test_helper")


context "Master Worker in general should" do
  def dump_object data
    t = Marshal.dump(data)
    t.length.to_s.rjust(9,'0') + t
  end

  setup do
    @master_worker = BackgrounDRb::MasterWorker.new
    @master_worker.post_init
    class << @master_worker
      attr_accessor :outgoing_data
      attr_accessor :key,:live_workers,:excpetion_type

      def packet_classify(original_string)
        word_parts = original_string.split('_')
        return word_parts.map { |x| x.capitalize}.join
      end

      def gen_worker_key(worker_name,worker_key = nil)
        return worker_name if worker_key.nil?
        return "#{worker_name}_#{worker_key}".to_sym
      end
      def ask_worker key,data
        case @excpetion_type
        when :disconnect
          raise Packet::DisconnectError.new("boy")
        when :generic
          raise "Crap"
        else
          @key = key
          @outgoing_data = data
        end
      end

      def start_worker data
        @outgoing_data = data
      end

      def ask_for_exception type
        @excpetion_type = type
      end
    end

    class DummyLogger
      def method_missing method_id,*args; "boy"; end
    end
    logger = DummyLogger.new
    @master_worker.debug_logger = logger
  end

  specify "read data according to binary protocol and recreate objects" do
    sync_request = {
      :type=>:sync_invoke, :arg=>"boy", :worker=>:foo_worker, :worker_method=>"barbar"
    }
    @master_worker.expects(:method_invoke).with(sync_request).returns(nil)
    @master_worker.receive_data(dump_object(sync_request))
  end

  specify "ignore errors while recreating object" do
    sync_request = {
      :type=>:sync_invoke, :arg=>"boy", :worker=>:foo_worker, :worker_method=>"barbar"
    }
    foo = dump_object(sync_request)
    foo[0] = 'h'
    @master_worker.expects(:method_invoke).never
    @master_worker.receive_data(foo)
  end

  specify "should route async requests" do
    b = {
      :type=>:async_invoke, :arg=>"boy", :worker=>:foo_worker, :worker_method=>"barbar"
    }
    @master_worker.receive_data(dump_object(b))
    @master_worker.outgoing_data.should == {:type=>:request, :data=>{:worker_method=>"barbar", :arg=>"boy"}, :result=>false}
    @master_worker.key.should == :foo_worker
  end

  specify "should route sync requests and return results" do
    a = {:type=>:sync_invoke, :arg=>"boy", :worker=>:foo_worker, :worker_method=>"barbar"}
    @master_worker.receive_data(dump_object(a))
    @master_worker.outgoing_data.should == {:type=>:request, :data=>{:worker_method=>"barbar", :arg=>"boy"}, :result=>true}
    @master_worker.key.should == :foo_worker
  end

  specify "should route start worker requests" do
    d = {:worker_key=>"boy", :type=>:start_worker, :worker=>:foo_worker}
    @master_worker.receive_data(dump_object(d))
    @master_worker.outgoing_data.should == {:type=>:start_worker, :worker_key=>"boy", :worker=>:foo_worker}
  end

  # FIXME: this test should be further broken down
  specify "should run delete worker requests itself" do
    e = {:worker_key=>"boy", :type=>:delete_worker, :worker=>:foo_worker}
    @master_worker.expects(:delete_drb_worker).returns(nil)
    @master_worker.receive_data(dump_object(e))
  end

  specify "should route worker info requests" do
    g = {:worker_key=>"boy", :type=>:worker_info, :worker=>:foo_worker}
    t_reactor = stub()
    live_workers = stub()
    live_workers.expects(:[]).returns(nil)
    t_reactor.expects(:live_workers).returns(live_workers)
    @master_worker.expects(:send_object).with({:worker_key=>"boy", :worker=>:foo_worker, :status=>:stopped}).returns(true)
    @master_worker.expects(:reactor).returns(t_reactor)
    @master_worker.receive_data(dump_object(g))
  end

  specify "should route all_worker_info requests" do
    f = {:type=>:all_worker_info}
    t_reactor = stub()
    live_workers = stub()
    live_workers.stubs(:each).returns(:foo,mock())
    t_reactor.expects(:live_workers).returns(live_workers)
    @master_worker.expects(:send_object).returns(true)
    @master_worker.expects(:reactor).returns(t_reactor)

    @master_worker.receive_data(dump_object(f))
  end

  specify "should route worker result requests" do
    c = {:type=>:get_result, :worker=>:foo_worker, :job_key=>:start_message}
    @master_worker.receive_data(dump_object(c))
    @master_worker.outgoing_data.should == {:type=>:get_result, :data=>{:job_key=>:start_message}, :result=>true}
  end

  specify "should remove the worker from list if error while fetching results" do
    c = {:type=>:get_result, :worker=>:foo_worker, :job_key=>:start_message}
    @master_worker.ask_for_exception(:disconnect)
    t_reactor = mock()
    live_workers = mock()
    live_workers.expects(:delete).returns(true)
    t_reactor.expects(:live_workers).returns(live_workers)
    @master_worker.expects(:reactor).returns(t_reactor)
    @master_worker.receive_data(dump_object(c))
  end

  specify "should ignore generic exceptions while fetching results" do
    c = {:type=>:get_result, :worker=>:foo_worker, :job_key=>:start_message}
    @master_worker.ask_for_exception(:generic)
    @master_worker.receive_data(dump_object(c))
    @master_worker.outgoing_data.should == nil
  end
end
