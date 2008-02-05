require 'rake'
require 'rubygems'
require 'rake/testtask'
require 'rake/rdoctask'
require 'spec/rake/spectask'
require 'rake/contrib/sshpublisher'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the backgroundrb plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc "Run all specs"
Spec::Rake::SpecTask.new('specs') do |t|
  t.spec_opts = ["--format", "specdoc"]
  t.libs = ['lib', 'server/lib' ]
  t.spec_files = FileList['specs/**/*_spec.rb']
end

desc "RCov"
Spec::Rake::SpecTask.new('rcov') do |t|
  t.spec_files = FileList['specs/**/*_spec.rb']
  t.libs = ['lib', 'server/lib' ]
  t.rcov = true
end

desc 'Generate documentation for the backgroundrb plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Backgroundrb'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('LICENSE')
  rdoc.rdoc_files.include('lib/*.rb')
  rdoc.rdoc_files.include('framework/*.rb')
  rdoc.rdoc_files.include('server/*.rb')
  rdoc.template = 'jamis'
end

module Rake
  class BackgrounDRbPublisher <  SshDirPublisher
    attr_reader :project, :proj_id, :user
    def initialize(projname, user)
      super(
        "#{user}@rubyforge.org",
        "/var/www/gforge-projects/backgroundrb",
        "rdoc")
    end
  end
end

desc "Publish documentation to Rubyforge"
task :publish_rdoc => [:rdoc] do
  user = ENV['RUBYFORGE_USER']
  publisher = Rake::BackgrounDRbPublisher.new('backgroundrb', user)
  publisher.upload
end

