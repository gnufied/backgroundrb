module BackgrounDRb
  module ClientHelper
    def gen_worker_key(worker_name,worker_key = nil)
      return worker_name if worker_key.nil?
      return "#{worker_name}_#{worker_key}".to_sym
    end
  end
end
