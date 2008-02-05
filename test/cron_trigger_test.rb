require File.join(File.dirname(__FILE__) + "/bdrb_test_helper")
require "meta_worker" 

context "Cron Trigger should" do 
  setup do 
    BackgrounDRb::MetaWorker.worker_name = "hello_worker"
    class BackgrounDRb::MetaWorker
      attr_accessor :outgoing_data
      attr_accessor :incoming_data
      def send_data(data)
        @outgoing_data = data
      end
      def ivar var
        instance_variable_get(:"@#{var}")
      end
      def start_reactor; end
    end
    @klass = BackgrounDRb::MetaWorker
  end
  
  specify "run task each second for no option" do
    t_arg = { :foo => { :trigger_args => "*/5 * * * * *"}}
    
    @klass.any_instance.stubs(:worker_options).returns(:schedule => t_arg)
    meta_worker = @klass.start_worker
    meta_worker.ivar(:my_schedule).should.not.be(nil)
    meta_worker.ivar(:my_schedule).should == t_arg
  end
  
  xspecify "run task each minute for minute option" do
    
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
