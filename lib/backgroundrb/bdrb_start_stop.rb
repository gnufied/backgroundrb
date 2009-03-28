module BackgrounDRb
  class StartStop
    def kill_process arg_pid_file
      pid = nil
      pid = File.open(arg_pid_file, "r") { |pid_handle| pid_handle.gets.strip.chomp.to_i }
      pgid =  Process.getpgid(pid)
      puts "Stopping BackgrounDRb with pid #{pid}...."
      Process.kill('-TERM', pgid)
      File.delete(arg_pid_file) if File.exists?(arg_pid_file)
      puts "Success!"
    end


    def running?; File.exists?(PID_FILE); end

    def really_running? pid
      begin
        Process.kill(0,pid)
        true
      rescue Errno::ESRCH
        puts "pid file exists but process doesn't seem to be running restarting now"
        false
      end
    end

    def try_restart
      pid = nil
      pid = File.open(PID_FILE, "r") { |pid_handle| pid_handle.gets.strip.chomp.to_i }
      if really_running? pid
        puts "pid file already exists, exiting..."
        exit(-1)
      end
    end

    def start
      if fork
        sleep(5)
        exit(0)
      else
        try_restart if running?
        puts "Starting BackgrounDRb .... "
        op = File.open(PID_FILE, "w")
        op.write(Process.pid().to_s)
        op.close
        if BDRB_CONFIG[:backgroundrb][:log].nil? or BDRB_CONFIG[:backgroundrb][:log] != 'foreground'
          redirect_io(SERVER_LOGGER)
        end
        BackgrounDRb::MasterProxy.new()
      end
    end

    # Free file descriptors and
    # point them somewhere sensible
    # STDOUT/STDERR should go to a logfile
    def redirect_io(logfile_name)
      begin; STDIN.reopen "/dev/null"; rescue ::Exception; end

      if logfile_name
        begin
          STDOUT.reopen logfile_name, "a"
          STDOUT.sync = true
        rescue ::Exception
          begin; STDOUT.reopen "/dev/null"; rescue ::Exception; end
        end
      else
        begin; STDOUT.reopen "/dev/null"; rescue ::Exception; end
      end

      begin; STDERR.reopen STDOUT; rescue ::Exception; end
      STDERR.sync = true
    end


    def stop
      pid_files = Dir["#{RAILS_HOME}/tmp/pids/backgroundrb_*.pid"]
      pid_files.each { |x| kill_process(x) }
    end
  end
end
