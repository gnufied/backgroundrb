require File.join(File.dirname(__FILE__) + "/../bdrb_test_helper")
require File.join(RAILS_HOME + "/config/environment")
require "backgroundrb"

context "Worker Proxy in general" do
  setup do
    @cluster_conn = mock
    @worker_proxy = BackgrounDRb::RailsWorkerProxy.new(:hello_worker,nil,@cluster_conn)
  end
  specify "should let you fetch results" do
    @cluster_conn.expects(:backend_connections).returns([])
    foo = @worker_proxy.ask_result(:foobar)
    foo.should.be nil
  end

  specify "should let you invoke send_request method" do

  end

  specify "should let you invoke delete method" do

  end

  specify "should let you invoke worker_info method" do

  end

  specify "should let you invoke ask_status method" do

  end
end
