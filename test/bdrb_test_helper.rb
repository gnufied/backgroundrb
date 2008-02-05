require "rubygems"
require "mocha"
require "test/spec"
require "active_record" 
require "active_support" 

RAILS_HOME = File.expand_path(File.join(File.dirname(__FILE__) + "/../../../.."))
PACKET_APP = RAILS_HOME + "/vendor/plugins/backgroundrb"
WORKER_ROOT = RAILS_HOME + "/lib/workers"
SERVER_LOGGER = RAILS_HOME + "/log/backgroundrb_server.log"

["server","framework","lib"].each { |x| $LOAD_PATH.unshift(PACKET_APP + "/#{x}")}
$LOAD_PATH.unshift(WORKER_ROOT)

# require "#{PACKET_APP}/server/master_worker"
require "packet"
require "meta_worker"
require "cron_trigger"
require "trigger"
require "log_worker"
require "yaml"
require "erb"


# there should be a way to stub out reactor loop of bdrb

