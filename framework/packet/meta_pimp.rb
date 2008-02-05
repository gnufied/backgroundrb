# Class acts as a pimp for workers, which doesn't have a manually created pimp
# The idea behind a manually added pimp is to let client handle low level messaging
# beween workers. A meta pimp, does it for you.
class Packet::MetaPimp < Packet::Pimp
  # initializer of pimp
  attr_accessor :callback_hash
  attr_accessor :worker_status, :worker_key,:worker_name
  def pimp_init
    @callback_hash ||= {}
    @worker_status = nil
    @worker_result = nil
    @worker_key = nil
    @tokenizer = BinParser.new
  end

  # will be invoked whenever there is a response from the worker
  def receive_data p_data
    @tokenizer.extract(p_data) do |b_data|
      t_data = Marshal.load(b_data)
      handle_object(t_data)
    end
  end

  def handle_object data_options = {}
    case data_options[:type]
    when :request
      process_request(data_options)
    when :response
      process_response(data_options)
    when :status
      save_worker_status(data_options)
    when :result
      save_worker_result(data_options)
    end
  end

  def save_worker_result(data_options = { })
    @worker_result = data_options[:data]
  end

  def save_worker_status(data_options = { })
    # @worker_status = data_options[:data]
    reactor.update_result(worker_key,data_options[:data])
  end

  def process_request(data_options = {})
    if requested_worker = data_options[:requested_worker]
      reactor.live_workers[requested_worker].send_request(data_options)
      #workers[requested_worker].send_request(data_options)
    end
  end

  def process_response(data_options = {})
    if callback_signature = data_options[:callback_signature]
      callback = callback_hash[callback_signature]
      callback.invoke(data_options)
    elsif client_signature = data_options[:client_signature]
      # method writes to the tcp master connection loop
      begin
        reactor.connections[client_signature].instance.worker_receive(data_options)
      rescue
      end
    end
  end

  # can be used to send request to correspoding worker
  def send_request(data_options = { })
    if callback = data_options[:callback]
      callback_hash[callback.signature] = callback
      data_options.delete(:callback)
      data_options[:callback_signature] = callback.signature
      send_data(data_options)
    else
      send_data(data_options)
    end
  end
end

