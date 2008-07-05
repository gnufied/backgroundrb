require File.join(File.dirname(__FILE__) + "/../bdrb_test_helper")
require File.join(RAILS_HOME + "/config/environment")
require "backgroundrb"

context "For Cluster connection" do
  class BackgrounDRb::Connection
    attr_accessor :server_ip,:server_port,:cluster_conn,:connection_status
    def initialize ip,port,cluster_connection
      @server_ip = ip
      @server_port = port
    end
  end

  setup do
    BDRB_CONFIG = {:schedules=> {
        :foo_worker => { :barbar=>{:trigger_args=>"*/5 * * * * * *"}}},
      :backgroundrb=>{:port=>11008, :ip=>"0.0.0.0", :environment=> "production"},
      :client => "localhost:11001,localhost:11002"
    }

    @cluster_connection = BackgrounDRb::ClusterConnection.new
    class << @cluster_connection
      def ivar(var)
        return instance_variable_get("@#{var}")
      end
    end
  end

  specify "should read config file and connect to specified servers" do
    @cluster_connection.backend_connections.length.should == 2
    @cluster_connection.bdrb_servers.length.should == 2
    @cluster_connection.ivar(:round_robin).length.should == 2
    @cluster_connection.backend_connections[0].server_info.should == "localhost:11001"
  end

  specify "should return worker chosen in round robin manner if nothing specified" do
    t_conn = @cluster_connection.choose_server
    t_conn.server_info.should == "localhost:11001"
    t_conn = @cluster_connection.choose_server
    t_conn.server_info.should == "localhost:11002"
  end

  specify "should return connection from chosen host if specified" do
    t_conn = @cluster_connection.find_connection("localhost:11001")
    t_conn.server_info.should == "localhost:11001"
  end

  specify "should return connection from local host if specified" do
    t_conn = @cluster_connection.find_local
    t_conn.server_info.should == "0.0.0.0:11008"
  end
end

context "For single connections" do
  class BackgrounDRb::Connection
    attr_accessor :server_ip,:server_port,:cluster_conn,:connection_status
    def initialize ip,port,cluster_connection
      @server_ip = ip
      @server_port = port
    end
  end

  setup do
    BDRB_CONFIG = {:schedules=> {
        :foo_worker => { :barbar=>{:trigger_args=>"*/5 * * * * * *"}}},
      :backgroundrb=>{:port=>11008, :ip=>"0.0.0.0", :environment=> "production"}
    }

    @cluster_connection = BackgrounDRb::ClusterConnection.new
    class << @cluster_connection
      def ivar(var)
        return instance_variable_get("@#{var}")
      end
    end
  end

  specify "should read config file and connect to servers" do
    @cluster_connection.backend_connections.length.should == 1
    @cluster_connection.bdrb_servers.length.should == 1
    @cluster_connection.ivar(:round_robin).length.should == 1
    @cluster_connection.backend_connections[0].server_info.should == "0.0.0.0:11008"
  end
end
