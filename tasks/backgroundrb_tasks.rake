namespace :backgroundrb do
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
