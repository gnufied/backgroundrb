require File.join(File.dirname(__FILE__) + "/../socket_mocker")
require File.join(File.dirname(__FILE__) + "/../bdrb_test_helper")
require File.join(File.dirname(__FILE__) + "/../bdrb_client_test_helper")

context "For Actual BackgrounDRB connection" do
  specify "in case of timeout connection status should be false" do
    @cluster = mock()
    @connection = BackgrounDRb::Connection.new('localhost',1267,@cluster)
    @connection.establish_connection
  end
end
