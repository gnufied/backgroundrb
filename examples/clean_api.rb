# To execute task without a job key
# Current API
MiddleMan.ask_work(:worker => :foo_worker, :worker_method => :some_work, :data => "Hello World")

# new API
worker = MiddleMan.worker(:foo_worker)
worker.some_work("hello World")

# to execute task in single step
MiddleMan.worker(:foo_worker).some_work("hello World")


# To start a worker

# current API
MiddleMan.new_worker(:worker => :foo_worker, :job_key => "wow",:data => "Hello World")

# new API
worker = MiddelMan.new_worker(:foo_worker,:job_key => "Wow",:data => "Wow man",\
                              :schedule => { :hello_world => { :trigger_args => "*/5 * * * * * *",:data => "hello_world" }})

worker.hello_world("Wow man")
worker.delete

# to Ask status
# Current API
MiddleMan.ask_status(:worker => :foo_worker)

# new API
MiddleMan.worker(:foo_worker).ask_status

# To delete a worker
worker = MiddleMan.worker(:foo_worker,:job_key => "Hello World")
worker.delete

# To delete a worker in single Step
MiddleMan.worker(:foo_worker,:job_key => "Hello World").delete

# to Use send_request, idea # 1
worker = MiddleMan.worker(:foo_worker,:job_key => "Hello World")
worker.some_work(:block => true, :args => "Hello World")

# To use send_request, idea # 2
worker = MiddleMan.worker(:foo_worker,:job_key => "Hello World")
worker.fetch(:some_work,:args => "Hello World")

# To use send_request idea # 3
worker = MiddleMan.worker(:foo_worker,:job_key => "Hello World")
worker.some_work(:block => true, :data => "Hello World")


# To use send_request in one line
MiddleMan.worker(:foo_worker,:job_key => "Hello_world").fetch(:some_work, :args => "Hello World")

# To use send_request in one line using idea # 3
MiddleMan.worker(:foo_worker,:job_key => "foo").some_work(:block => true,:data => "Hello_world ")

# To use send_request on one line using idea #4
MiddleMan.worker(:foo_worker,:job_key => "foo").some_work("Hello World", true)

# Current send_request API
MiddleMan.send_request(:worker => :foo_worker,:job_key => "Hello World",:worker_method => :some_work,:data => "Hello_world")

# To use worker_info methods

# Current API
MiddleMan.worker_info(:worker => :foo_worker)

MiddleMan.all_worker_info

# New API
# For above case old API looks good enough







# For enabling reloading of workers when schedules are ready.
