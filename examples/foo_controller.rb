class FooController < ApplicationController
  layout :choose_layout
  def index
  end

  def mobile_action
    #render :layout => "mobile"
  end

  def start_worker
    MiddleMan.new_worker(:worker => :error_worker, :job_key => :hello_world,:data => "wow_man",:schedule => { :hello_world => { :trigger_args => "*/5 * * * * * *",:data => "hello_world" }})
    render :text => "worker starterd"
  end

  def stop_worker
    MiddleMan.delete_worker(:worker => :error_worker, :job_key => :hello_world)
    render :text => "worker deleted"
  end

  def invoke_worker_method
    worker_response = MiddleMan.send_request(:worker => :world_worker, :worker_method => :hello_world)
    render :text => worker_response
  end

  def renew
    MiddleMan.ask_work(:worker => :renewal_worker, :worker_method => :load_policies)
    render :text => "method invoked"
  end

  def ask_status
    t_response = MiddleMan.query_all_workers
    running_workers = t_response.map { |key,value| "#{key} = #{value}"}.join(',')
    render :text => running_workers
  end

  private
  def choose_layout
    if action_name == 'mobile_action'
      "mobile"
    else
      "foo"
    end
  end
end
