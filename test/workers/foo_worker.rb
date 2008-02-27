# Put your code that runs your task inside the do_work method it will be
# run automatically in a thread. You have access to all of your rails
# models.  You also get logger and results method inside of this class
# by default.


class FooWorker < BackgrounDRb::MetaWorker
  set_worker_name :foo_worker
  pool_size(5)
  
  def create(args = nil)
    puts "Loading foo worker"
    register_status("Running")
    p RAILS_ENV
    p Rails::VERSION::STRING
  end


  def foobar
    job_exit_status = 'FORCEABLY_DELETED'
    puts "#{Time.now} entered" 
    begin
      # Large batch job here
      sleep 30
    rescue
      job_exit_status = 'ERRORED_OUT'
      # Error processing here
    else
      job_exit_status = 'FINISHED_NORMALLY'
    ensure
      puts "#{Time.now} do worke exit status #{job_exit_status}" 
    end
  end
  
  def barbar(args = nil)
    logger.info "running bar bar #{Time.now}"
  end
end


