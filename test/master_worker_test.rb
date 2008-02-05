require File.join(File.dirname(__FILE__) + "/bdrb_test_helper")
require "#{PACKET_APP}/server/master_worker"

context "Master Worker in general should" do
  setup do
    master_worker = MasterWorker.new
  end
  xspecify "should invoke proper method for different requests" do

  end

  xspecify "should load proper environment from config file" do

  end
end
