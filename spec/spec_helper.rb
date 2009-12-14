require 'rubygems'
gem 'rspec', '>= 1.2.8'
require 'spec'
require File.join(File.dirname(__FILE__), '..', 'lib', 'almaz')
require 'base64'
require 'timecop'
require 'logger'

Spec::Runner.configure do |config|
  config.before(:all) {
    result = RedisRunner.start_detached
    raise("Could not start redis-server, aborting") unless result

    # yeah, this sucks, but it seems like sometimes we try to connect too quickly w/o it
    sleep 1

    # use database 15 for testing so we dont accidentally step on real data
    @db = Redis.new(:db => 15) #, :logger => Logger.new(STDOUT), :debug => true)
  }
  
  config.after(:each) {
    @db.flushdb
  }
  
  config.after(:all) {
    begin
      @db.quit
    ensure
      RedisRunner.stop rescue 'Oops'
    end
  }
end

def encode_credentials(username, password)
  "Basic " + Base64.encode64("#{username}:#{password}")
end


class ExampleSinatraApp < Sinatra::Base
  
  get '/awesome/controller' do
    'wooo hoo'
  end
  
end