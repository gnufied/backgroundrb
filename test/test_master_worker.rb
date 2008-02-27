require File.join(File.dirname(__FILE__) + "/bdrb_test_helper")


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

context "Master proxy for reloadable workers" do 
  BackgrounDRb::Config::RAILS_ENV = "production"
  CONFIG_FILE = { :backgroundrb => { :port => 11006,:ip => 'localhost',:environment => 'production'}}
  
  setup do 
    Packet::Reactor.stubs(:run)
    @master_proxy = BackgrounDRb::MasterProxy.new
  end
  
  specify "should load schedule of workers which are reloadable" do
    @master_proxy.find_reloadable_worker
    p @master_proxy.reloadable_workers
  end
  
  specify "should invoke worker methods which are ready to run" do
    
  end
  
  specify "should not run worker methods which are not ready to run" do
    
  end
end
