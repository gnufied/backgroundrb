require File.dirname(__FILE__) + '/test_helper'
WORKER_ROOT = RAILS_ROOT + "/lib/workers"
$LOAD_PATH.unshift(WORKER_ROOT)
require "mocha"

class Object
  def self.metaclass; class << self; self; end; end

  def self.iattr_accessor *args
    metaclass.instance_eval do
      attr_accessor *args
      args.each do |attr|
        define_method("set_#{attr}") do |b_value|
          self.send("#{attr}=",b_value)
        end
      end
    end

    args.each do |attr|
      class_eval do
        define_method(attr) do
          self.class.send(attr)
        end
        define_method("#{attr}=") do |b_value|
          self.class.send("#{attr}=",b_value)
        end
      end
    end
  end
end

module BackgrounDRb
  class WorkerDummyLogger
    def info(data)
    end
    def debug(data)
    end
    def error(data)
    end
  end
  class MetaWorker
    attr_accessor :logger
    attr_accessor :thread_pool
    iattr_accessor :worker_name
    iattr_accessor :no_auto_load

    def initialize
      @logger = WorkerDummyLogger.new
      @thread_pool = ThreadPool.new
    end
    
    def register_status(arg)
      @status = arg
    end
  end
  
  class ThreadPool
    def defer(args,&block)
      yield args
    end
  end
end

