namespace :backgroundrb do
  def setup_queue_migration
    config_file = "#{RAILS_ROOT}/config/database.yml"
    require "erb"
    require "active_record"
    config = YAML.load(ERB.new(IO.read(config_file)).result)
    env = ENV["env"] || 'development'
    ActiveRecord::Base.establish_connection(config[env])

    table_creation =<<-EOD
      create table bdrb_job_queues(
        id integer not null auto_increment primary key,
        args               blob,
        worker_name        varchar(255),
        worker_method      varchar(255),
        job_key            varchar(255),
        taken              tinyint,
        finished           tinyint,
        timeout            int,
        priority           int,
        submitted_at       datetime,
        started_at         datetime,
        finished_at        datetime,
        archived_at        datetime,
        tag                varchar(255),
        submitter_info     varchar(255),
        runner_info        varchar(255),
        worker_key         varchar(255)
      ) ENGINE=InnoDB;
    EOD
    connection = ActiveRecord::Base.connection
    begin
      connection.execute(table_creation)
    rescue ActiveRecord::StatementInvalid => e
      #puts e.message
    end
  end

  require 'yaml'
  desc 'Setup backgroundrb in your rails application'
  task :setup do
    script_dest = "#{RAILS_ROOT}/script/backgroundrb"
    script_src = File.dirname(__FILE__) + "/../script/backgroundrb"

    FileUtils.chmod 0774, script_src

    defaults = {:backgroundrb => {:ip => '0.0.0.0',:port => 11006 } }

    config_dest = "#{RAILS_ROOT}/config/backgroundrb.yml"

    unless File.exists?(config_dest)
        puts "Copying backgroundrb.yml config file to #{config_dest}"
        File.open(config_dest, 'w') { |f| f.write(YAML.dump(defaults)) }
    end

    unless File.exists?(script_dest)
        puts "Copying backgroundrb script to #{script_dest}"
        FileUtils.cp_r(script_src, script_dest)
    end

    workers_dest = "#{RAILS_ROOT}/lib/workers"
    unless File.exists?(workers_dest)
      puts "Creating #{workers_dest}"
      FileUtils.mkdir(workers_dest)
    end

    test_helper_dest = "#{RAILS_ROOT}/test/bdrb_test_helper.rb"
    test_helper_src = File.dirname(__FILE__) + "/../script/bdrb_test_helper.rb"
    unless File.exists?(test_helper_dest)
      puts "Copying Worker Test helper file #{test_helper_dest}"
      FileUtils.cp_r(test_helper_src,test_helper_dest)
    end

    worker_env_loader_dest = "#{RAILS_ROOT}/script/load_worker_env.rb"
    worker_env_loader_src = File.join(File.dirname(__FILE__),"..","script","load_worker_env.rb")
    unless File.exists? worker_env_loader_dest
      puts "Copying Worker envionment loader file #{worker_env_loader_dest}"
      FileUtils.cp_r(worker_env_loader_src,worker_env_loader_dest)
    end
    setup_queue_migration
  end

  desc 'Remove backgroundrb from your rails application'
  task :remove do
    script_src = "#{RAILS_ROOT}/script/backgroundrb"

    if File.exists?(script_src)
        puts "Removing #{script_src} ..."
        FileUtils.rm(script_src, :force => true)
    end

    test_helper_src = "#{RAILS_ROOT}/test/bdrb_test_helper.rb"
    if File.exists?(test_helper_src)
      puts "Removing backgroundrb test helper.."
      FileUtils.rm(test_helper_src,:force => true)
    end

    workers_dest = "#{RAILS_ROOT}/lib/workers"
    if File.exists?(workers_dest) && Dir.entries("#{workers_dest}").size == 2
        puts "#{workers_dest} is empty...deleting!"
        FileUtils.rmdir(workers_dest)
    end
  end
end
