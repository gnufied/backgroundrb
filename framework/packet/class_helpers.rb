module Packet
  module ClassHelpers
    def metaclass; class << self; self; end; end

    def iattr_accessor *args
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
    end # end of method iattr_accessor

    def cattr_reader(*syms)
      syms.flatten.each do |sym|
        next if sym.is_a?(Hash)
        class_eval(<<-EOS, __FILE__, __LINE__)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}
          @@#{sym}
        end

        def #{sym}
          @@#{sym}
        end
        EOS
      end
    end

    def cattr_writer(*syms)
      options = syms.last.is_a?(Hash) ? syms.pop : {}
      syms.flatten.each do |sym|
        class_eval(<<-EOS, __FILE__, __LINE__)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}=(obj)
            @@#{sym} = obj
        end

        #{"
        def #{sym}=(obj)
          @@#{sym} = obj
        end
        " unless options[:instance_writer] == false }
      EOS
     end
   end

   def cattr_accessor(*syms)
     cattr_reader(*syms)
     cattr_writer(*syms)
   end
   module_function :metaclass,:iattr_accessor, :cattr_writer, :cattr_reader, :cattr_accessor
  end # end of module ClassHelpers
end

