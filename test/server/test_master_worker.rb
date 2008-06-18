require File.join(File.dirname(__FILE__) + "/bdrb_test_helper")

context "Master proxy for reloadable workers" do 
  BackgrounDRb::Config::RAILS_ENV = "production"
  CONFIG_FILE = {:schedules=> 
    {
      :foo_worker => { :barbar => {:trigger_args=>"*/10 * * * * *", :data =>"Hello World" }},
      :bar_worker => { :do_job => {:trigger_args=>"*/10 * * * * *", :data =>"Hello World" }}
    }, 
    :backgroundrb=> {:log=>"foreground", :lazy_load=>true, :debug_log=>false, :environment=>"production", :port=>11006, :ip=>"localhost"}
  }
  
  setup do 
    Packet::Reactor.stubs(:run)
    @master_proxy = BackgrounDRb::MasterProxy.new
  end
  
  specify "should load schedule of workers which are reloadable" do
    @master_proxy.find_reloadable_worker
    @master_proxy.reloadable_workers.should.not.be []
    @master_proxy.reloadable_workers.should == [BarWorker]
    @master_proxy.worker_triggers.should.not.be {}
    assert @master_proxy.worker_triggers.keys.include?(:bar_worker)
    assert @master_proxy.worker_triggers[:bar_worker].keys.include?(:do_job)
    @master_proxy.worker_triggers[:bar_worker][:do_job].should.not.be { }
  end
  
  specify "load schedule should load schedule of worker specified" do
    require "bar_worker" 
    @master_proxy.load_reloadable_schedule(BarWorker).should.not.be { }
  end
  
  specify "should invoke worker methods which are ready to run" do
    
  end
  
  specify "should not run worker methods which are not ready to run" do
    
  end
end

context "Master Worker in general should" do
  specify "read data according to binary protocol and recreate objects" do

  end

  specify "ignore errors while recreating object" do

  end

  specify "extract worker and method and pass the request to appropriate worker" do

  end

  specify "ignore errors if sending request to worker failed" do

  end

  specify "handle status requests itself" do

  end

  specify "handle worker information requests itself" do

  end

  specify "ignore errors if sending response back to the client failed" do

  end

  specify "should load proper environment from config file" do
  end

  specify "reload workers which are to be loaded at proper interval" do
  end

  specify "log all the errors to the log file" do

  end

  specify "ignore errors if result returned by worker cant be contructed in an object" do

  end

  specify "return appropriate string message if results cant be constructed properly" do

  end
end

