# Backgroundrb
# FIXME: check if data that we are writing to the socket should end with newline
require "pathname"
require "packet" 
BACKGROUNDRB_ROOT = Pathname.new(RAILS_ROOT).realpath.to_s
require "bdrb_conn_error"

module BackgrounDRb
end
class BackgrounDRb::WorkerProxy
  include Packet::NbioHelper
  def self.init
    # @@config = YAML.load(File.open("#{BACKGROUNDRB_ROOT}/config/backgroundrb.yml"))
    @@config = YAML.load(ERB.new(IO.read("#{BACKGROUNDRB_ROOT}/config/backgroundrb.yml")).result)
    @@server_ip = @@config[:backgroundrb][:ip]
    @@server_port = @@config[:backgroundrb][:port]
    new
  end

  def establish_connection
    @tokenizer = BinParser.new
    begin
      timeout(3) do
        @connection = TCPSocket.open(@@server_ip, @@server_port)
        @connection.setsockopt(Socket::IPPROTO_TCP,Socket::TCP_NODELAY,1)
      end
      @connection_status = true
    rescue Timeout::Error
      @connection_status = false
    rescue Exception => e
      @connection_status = false
    end
  end
  
  def write_data data
    t_length = data.length
    begin
      loop do 
        break if t_length <= 0
        written_length = @connection.write(data)
        @connection.flush
        data = data[written_length..-1]
        t_length = data.length
      end
    rescue Errno::EAGAIN
      return
    rescue Errno::EPIPE
      raise BackgrounDRb::BdrbConnError.new("Error while writing")
    rescue
      raise BackgrounDRb::BdrbConnError.new("Error while writing")
    end
  end
  
  def dump_object data
    object_dump = Marshal.dump(data)
    dump_length = object_dump.length.to_s
    length_str = dump_length.rjust(9,'0')
    final_data = length_str + object_dump
    write_data(final_data)
  end

  def ask_work p_data
    p_data[:type] = :do_work
    establish_connection()
    raise BackgrounDRb::BdrbConnError.new("Not able to connect") unless @connection_status
    dump_object(p_data)
    @connection.close
  end

  def new_worker p_data
    p_data[:type] = :start_worker
    establish_connection
    raise BackgrounDRb::BdrbConnError.new("Not able to connect") unless @connection_status
    dump_object(p_data)
    return p_data[:job_key]
    @connection.close
  end
  
  def worker_info(p_data)
    p_data[:type] = :worker_info
    establish_connection
    raise BackgrounDRb::BdrbConnError.new("Not able to connect") unless @connection_status
    dump_object(p_data)
    return read_from_bdrb()
  end
  
  
  def all_worker_info
    p_data = { }
    p_data[:type] = :all_worker_info
    establish_connection
    raise BackgrounDRb::BdrbConnError.new("Not able to connect") unless @connection_status
    dump_object(p_data)
    return read_from_bdrb
  end

  def delete_worker p_data
    p_data[:type] = :delete_worker
    establish_connection
    raise BackgrounDRb::BdrbConnError.new("Not able to connect") unless @connection_status
    dump_object(p_data)
    @connection.close
  end

  def read_object
    sock_data = ""
    begin
      while(sock_data << @connection.read_nonblock(1023)); end
    rescue Errno::EAGAIN
      @tokenizer.extract(sock_data) { |b_data| return b_data }
    rescue
      raise BackgrounDRb::BdrbConnError.new("Not able to connect")
    end
  end

  def query_all_workers
    p_data = { }
    p_data[:type] = :all_worker_status
    establish_connection
    raise BackgrounDRb::BdrbConnError.new("Not able to connect") unless @connection_status
    dump_object(p_data)
    return read_from_bdrb
  end

  def ask_status(p_data)
    p_data[:type] = :get_status
    establish_connection()

    raise BackgrounDRb::BdrbConnError.new("Not able to connect") unless @connection_status
    dump_object(p_data)
    return read_from_bdrb
  end
  
  def read_from_bdrb(timeout = 3)
    begin
      ret_val = select([@connection],nil,nil,timeout)
      return nil unless ret_val
      raw_response = read_object()
      master_response = Marshal.load(raw_response)
      @connection.close
      return master_response
    rescue
      return nil
    end
  end

  def send_request(p_data)
    p_data[:type] = :get_result
    establish_connection()

    raise BackgrounDRb::BdrbConnError.new("Not able to connect") unless @connection_status
    dump_object(p_data)
    return read_from_bdrb(nil)
  end
end

MiddleMan = BackgrounDRb::WorkerProxy.init

