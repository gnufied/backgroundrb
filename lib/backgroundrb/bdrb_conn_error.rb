module BackgrounDRb
  class BdrbConnError < RuntimeError
    attr_accessor :message
    def initialize(message)
      @message = message
    end
  end
  class NoServerAvailable < RuntimeError
    attr_accessor :message
    def initialize(message)
      @message = message
    end
  end

  class NoJobKey < RuntimeError; end
end
