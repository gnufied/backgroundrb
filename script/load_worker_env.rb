#!/usr/bin/env ruby

RAILS_HOME = File.expand_path(File.join(File.dirname(__FILE__),".."))
BDRB_HOME = File.join(RAILS_HOME,"vendor","plugins","backgroundrb")

["server","server/lib","lib","lib/backgroundrb"].each { |x| $LOAD_PATH.unshift(BDRB_HOME + "/#{x}")}

$LOAD_PATH.unshift(File.join(RAILS_HOME,"lib","workers"))

require "yaml"
require "erb"
require "logger"
require "optparse"
require "bdrb_config"

require RAILS_HOME + "/config/boot"
require "active_support"

CONFIG_FILE = BackgrounDRb::Config.read_config("#{RAILS_HOME}/config/backgroundrb.yml")

require RAILS_HOME + "/config/environment"
require "backgroundrb_server"

