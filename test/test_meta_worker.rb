require File.join(File.dirname(__FILE__) + "/bdrb_test_helper")
require "meta_worker"

context "A Meta Worker should" do
  setup do
    BackgrounDRb::MetaWorker.worker_name = "hello_worker"
    db_config = { :development => 
      { :adapter => "mysql",:database => "rails_sandbox_development" , 
        :username => "root",:password => "foobar"
      },
      :test => { 
        :adapter => "mysql", :database => "rails_sandbox_test",
        :username => "root", :password => "foobar",
      },
      :production => { 
        :adapter => "mysql", :database => "rails_sandbox_production",
        :username => "root", :password => "foobar"
      }
    }
    
    class BackgrounDRb::MetaWorker
      attr_accessor :outgoing_data
      attr_accessor :incoming_data
      def send_data(data)
        @outgoing_data = data
      end

      def start_reactor; end
    end
    meta_worker = BackgrounDRb::MetaWorker.start_worker
  end

  specify "load appropriate db environment from config file" do
    ActiveRecord::Base.connection.current_database.should == "rails_sandbox_production"
  end
  
  xspecify "remove a task from schedule if end time is reached" do 
  end

  xspecify "load appropriate schedule from config file" do
  end

  xspecify "register status request should be send out to master" do
  end
  
  xspecify "load schedule from passed arguments to start worker" do
    
  end
  
  xspecify "should have access to logger objects" do
    
  end
  
  xspecify "logger object should support info, error and debug methods" do
    
  end
  
  xspecify "invoke particular method based on user arguments" do
    
  end
  
  xspecify "should send results back to master only when response can be dumped" do
    
  end
  
  xspecify "should check for arguments of the invoked worker method" do
    
  end
end

context "Cron Trigger should" do 
  setup do 
    BackgrounDRb::MetaWorker.worker_name = "hello_worker"
    class BackgrounDRb::MetaWorker
      attr_accessor :outgoing_data
      attr_accessor :incoming_data
      set_no_auto_load(true)
      def send_data(data)
        @outgoing_data = data
      end
      def ivar var
        instance_variable_get(:"@#{var}")
      end
      # method would disable starting of reactor loop
      def start_reactor; end
    end
    @klass = BackgrounDRb::MetaWorker
  end
  
  def mock_worker(t_arg,next_time)
    puts "hello world" 
    @klass.any_instance.stubs(:worker_options).returns(:schedule => t_arg)
    meta_worker = @klass.start_worker
    meta_worker.ivar(:my_schedule).should.not.be(nil)
    meta_worker.ivar(:my_schedule).should == t_arg
    meta_worker.ivar(:worker_method_triggers).should.not.be nil
    firetime = meta_worker.ivar(:worker_method_triggers)[:foo][:runtime]
    firetime.should.not.be.nil
    time_object = mock()
    proper_time = Time.now + next_time
    Time.stubs(:now).returns(time_object,proper_time)
    [meta_worker,time_object,firetime]
  end
  
  specify "run task each 5 second for no option" do
    t_arg = { :foo => { :trigger_args => "*/5 * * * * *"}}
    meta_worker,time_object,firetime = *mock_worker(t_arg,15)
    time_object.stubs(:to_i).returns(firetime + 1)
    meta_worker.expects(:foo).once
    meta_worker.check_for_timer_events
  end
  
  specify "should not run the task if time to run has not arrived" do
    t_arg = { :foo => { :trigger_args => "*/5 * * * * *"}}
    meta_worker,time_object,firetime = *mock_worker(t_arg,10)
    time_object.stubs(:to_i).returns(firetime - 2)
    meta_worker.expects(:foo).never
    meta_worker.check_for_timer_events
  end
  
  specify "run task each minute for minute option" do
    t_arg = { :foo => { :trigger_args => "0 1 * * * *"}}
    
    meta_worker,time_object,firetime = *mock_worker(t_arg,2*60)
    
    time_object.stubs(:to_i).returns(firetime + 2)
    meta_worker.expects(:foo).once
    meta_worker.check_for_timer_events
  end
  
  specify "should not for minute arguments if time is not reached" do
    t_arg = { :foo => { :trigger_args => "0 1 * * * *"}}
    meta_worker,time_object,firetime = *mock_worker(t_arg,2*60)
    
    time_object.stubs(:to_i).returns(firetime - 10)
    meta_worker.expects(:foo).never
    meta_worker.check_for_timer_events
  end
  
  xspecify "run at specified hour for hourly option" do
    
  end
  
  xspecify "run at specified day for day option" do
    
  end
  
  xspecify "run at specified week day for specified option" do
    
  end
  
  xspecify "run in appropriate month for speficied option" do
    
  end
  
  xspecify "run in appropriate year for specified option" do
    
  end
end
