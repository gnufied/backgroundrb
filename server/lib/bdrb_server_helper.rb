module BackgrounDRb
  module BdrbServerHelper
    def load_data data
      begin
        return Marshal.load(data)
      rescue
        error_msg = $!.message
        if error_msg =~ /^undefined\ .+\ ([A-Z].+)/
          file_name = $1.underscore
          begin
            require file_name
            return Marshal.load(data)
          rescue
            return nil
          end
        else
          return nil
        end
      end # end of load_data method
    end
  end
end
