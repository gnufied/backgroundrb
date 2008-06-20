require "rubygems"
require "mocha"
require "test/spec"
require "active_record"
require "active_support"
require "yaml"
require "erb"

RAILS_HOME = File.expand_path(File.join(File.dirname(__FILE__) + "/../../../.."))
PACKET_APP = RAILS_HOME + "/vendor/plugins/backgroundrb"
WORKER_ROOT = RAILS_HOME + "/vendor/plugins/backgroundrb/test/workers"
SERVER_LOGGER = RAILS_HOME + "/log/backgroundrb_debug.log"

["server","server/lib","lib","lib/backgroundrb"].each { |x| $LOAD_PATH.unshift(PACKET_APP + "/#{x}")}
$LOAD_PATH.unshift(WORKER_ROOT)

require "packet"
require "bdrb_config"


require "backgroundrb_server"


