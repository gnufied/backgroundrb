require "socket"
require "yaml"
require "forwardable"
require "ostruct"
require "thread"

require "packet/bin_parser"
require "packet/packet_guid"
require "packet/class_helpers"
require "packet/double_keyed_hash"
require "packet/event"
require "packet/periodic_event"
require "packet/disconnect_error"
require "packet/callback"
require "packet/nbio"
require "packet/pimp"
require "packet/meta_pimp"
require "packet/core"
require "packet/packet_master"
require "packet/connection"
require "packet/worker"


# This file is just a runner of things and hence does basic initialization of thingies required for running
# the application.

PACKET_APP = File.expand_path'../' unless defined?(PACKET_APP)

module Packet
  VERSION='0.1.3'
end
