require File.join(File.dirname(__FILE__) + "/bdrb_test_helper")
require File.join(RAILS_HOME + "/config/environment")
require "backgroundrb"

context "Backgroundrb connection in general should" do
  specify "ask_work should throw exception if connection cant be established" do
    should.raise(BackgrounDRb::BdrbConnError) do
      MiddleMan.ask_work(:worker => :hello_worker, :worker_method => :say_hello)
    end
  end
end


