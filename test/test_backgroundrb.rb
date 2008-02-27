require File.join(File.dirname(__FILE__) + "/bdrb_test_helper")
require File.join(RAILS_HOME + "/config/environment")
require "backgroundrb"

context "Backgroundrb connection in general should" do
  specify "ask_work should throw exception if connection cant be established" do
    should.raise(BackgrounDRb::BdrbConnError) do
      MiddleMan.ask_work(:worker => :hello_worker, :worker_method => :say_hello)
    end
  end

  specify "connect to host, port specified in configuration file" do

  end

  specify "write the data according to the binary protocol to the socket" do

  end

  specify "read the data according to the binary protocol and pass to controller" do

  end

  specify "ignore errors while recreating objects from dumps" do

  end

  specify "raise error if writing to the socket failed" do

  end
end



