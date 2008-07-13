class BdrbJobQueue < ActiveRecord::Base
  validates_uniqueness_of :job_key,:scope => [:worker_name,:worker_key]
  def self.find_next(worker_name,worker_key = nil)
    returned_job = nil
    transaction do
      unless worker_key
        t_job = find(:first,:conditions => { :worker_name => worker_name,:taken => 0},:lock => true)
      else
        t_job = find(:first,:conditions => { :worker_name => worker_name,:taken => 0,:worker_key => worker_key },:lock => true)
      end
      if t_job
        t_job.taken = 1
        t_job.started_at = Time.now
        t_job.save
        returned_job = t_job
      end
    end
    returned_job
  end

  def release_job
    self.class.transaction do
      self.taken = 0
      self.started_at = nil
      self.save
    end
  end

  def self.insert_job(options = { })
    transaction do
      options.merge!(:submitted_at => Time.now,:finished => 0,:taken => 0)
      t_job = new(options)
      t_job.save
    end
  end

  def finish!
    self.class.transaction do
      self.finished = 1
      self.finished_at = Time.now
      self.save
    end
  end
end

