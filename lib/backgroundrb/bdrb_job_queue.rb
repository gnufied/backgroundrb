# Model for storing jobs/tasks persisted to the database

class BdrbJobQueue < ActiveRecord::Base
  validates_uniqueness_of :job_key,:scope => [:worker_name,:worker_key]
  # find next task from the table
  def self.find_next(worker_name,worker_key = nil)
    returned_job = nil
    transaction do
      unless worker_key
        #use ruby time stamps for time calculations as db might have different times than what is calculated by ruby/rails
        t_job = find(:first,:conditions => [" worker_name = ? AND taken = ? AND scheduled_at <= ? ", worker_name, 0, Time.now.utc ],:lock => true)
      else
        t_job = find(:first,:conditions => [" worker_name = ? AND taken = ? AND worker_key = ? AND scheduled_at <= ? ", worker_name, 0, worker_key, Time.now.utc ],:lock => true)
      end
      if t_job
        t_job.taken = 1
        t_job.started_at = Time.now.utc
        t_job.save
        returned_job = t_job
      end
    end
    returned_job
  end

  # release a job and mark it to be unfinished and free.
  # useful, if inside a worker, processing of this job failed and you want it to process later
  def release_job
    self.class.transaction do
      self.taken = 0
      self.started_at = nil
      self.save
    end
  end

  # insert a new job for processing. jobs added will be automatically picked by the appropriate worker
  def self.insert_job(options = { })
    transaction do
      options.merge!(:submitted_at => Time.now.utc,:finished => 0,:taken => 0)
      t_job = new(options)
      t_job.save
    end
  end

  # remove a job from table
  def self.remove_job(options = { })
    transaction do
      t_job_id = find(:first, :conditions => options.merge(:finished => 0,:taken => 0),:lock => true)
      delete(t_job_id)
    end
  end

  # Mark a job as finished
  def finish!
    self.class.transaction do
      self.finished = 1
      self.finished_at = Time.now.utc
      self.job_key = "finished_#{Time.now.utc.to_i}_#{job_key}"
      self.save
    end
    Thread.current[:persistent_job_id] = nil
    Thread.current[:job_key] = nil
    nil
  end
end

