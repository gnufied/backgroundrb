class BarWorker < BackgrounDRb::MetaWorker
  set_worker_name :bar_worker
  reload_on_schedule true
  def create(args = nil)
  end
  
  def do_job(args)
    args + 10
  end
end
