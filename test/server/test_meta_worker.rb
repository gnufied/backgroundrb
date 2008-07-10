require File.join(File.dirname(__FILE__) + "/../bdrb_test_helper")
require "meta_worker"
require "chronic"

context "A Meta Worker should" do
  setup do
    options = {:schedules =>
      {
        :proper_worker => { :barbar => {:trigger_args=>"*/5 * * * * *", :data =>"Hello World" }},
        :bar_worker => { :do_job => {:trigger_args=>"*/5 * * * * *", :data =>"Hello World" }}
      },
      :backgroundrb => {:log => "foreground", :debug_log => false, :environment => "production", :port => 11006, :ip => "localhost"}
    }
    BDRB_CONFIG.set(options)

    BackgrounDRb::MetaWorker.worker_name = "hello_worker"

    class ProperWorker < BackgrounDRb::MetaWorker
      attr_accessor :outgoing_data
      attr_accessor :incoming_data
      set_worker_name :proper_worker
      def send_data(data)
        @outgoing_data = data
      end

      def start_reactor; end

      def ivar(var)
        instance_variable_get("@#{var}")
      end
    end
    @meta_worker = ProperWorker.start_worker
  end

  specify "load appropriate db environment from config file" do
    ENV["RAILS_ENV"] = BDRB_CONFIG[:backgroundrb][:environment]
    @meta_worker.send(:load_rails_env)
    ActiveRecord::Base.connection.current_database.should == "rails_sandbox_production"
  end


  specify "load appropriate schedule from config file" do
    @meta_worker.my_schedule.should.not == nil
    @meta_worker.my_schedule.should == {:barbar=>{:data=>"Hello World", :trigger_args=>"*/5 * * * * *"}}
    trigger = @meta_worker.ivar(:worker_method_triggers)
    trigger.should.not == nil
    trigger[:barbar][:data].should == "Hello World"
  end

  specify "load schedule from passed arguments to start worker" do

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

context "For unix schedulers" do
  specify "remove a task from schedule if end time is reached" do

  end
end

context "For cron scheduler" do
end

context "Worker without names" do
  specify "should throw an error on initialization" do
    options = {:schedules =>
      {
        :foo_worker => { :barbar => {:trigger_args=>"*/5 * * * * *", :data =>"Hello World" }},
        :bar_worker => { :do_job => {:trigger_args=>"*/5 * * * * *", :data =>"Hello World" }}
      },
      :backgroundrb => {:log => "foreground", :debug_log => false, :environment => "production", :port => 11006, :ip => "localhost"}
    }
    BDRB_CONFIG.set(options)

    BackgrounDRb::MetaWorker.worker_name = "hello_worker"

    class BoyWorker < BackgrounDRb::MetaWorker
      attr_accessor :outgoing_data
      attr_accessor :incoming_data
      def send_data(data)
        @outgoing_data = data
      end

      def start_reactor; end
    end
    should.raise { @meta_worker = BoyWorker.start_worker }
  end
end

context "Worker with options" do
  specify "should load schedule from passed options" do
    options = { :backgroundrb => {:log => "foreground", :debug_log => false, :environment => "production", :port => 11006, :ip => "localhost"}}
    BDRB_CONFIG.set(options)

    BackgrounDRb::MetaWorker.worker_name = "hello_worker"

    class CrapWorker < BackgrounDRb::MetaWorker
      set_worker_name :crap_worker
      set_no_auto_load true
      attr_accessor :outgoing_data
      attr_accessor :incoming_data
      def send_data(data)
        @outgoing_data = data
      end

      def start_reactor; end
      def ivar(var); instance_variable_get("@#{var}"); end
    end
    write_end = mock()
    read_end = mock()
    worker_options = { :write_end => mock(),:read_end => mock(),
      :options => {
        :data => "hello", :schedule => {
          :hello_world => { :trigger_args => "*/5 * * * * * *",
            :data => "hello_world"
          }
        }
      }
    }
    CrapWorker.any_instance.expects(:create).with("hello").returns(true)
    @meta_worker = CrapWorker.start_worker(worker_options)
    @meta_worker.my_schedule.should == {:hello_world=>{:data=>"hello_world", :trigger_args=>"*/5 * * * * * *"}}
  end
end
