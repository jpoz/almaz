require 'rubygems'
require 'sinatra'
require 'redis'
require 'json'
require 'cgi'

class Almaz
  @@session_variable = 'session_id'
  @@redis_config = {:db => 0}
  @@expiry = 60 * 60 # 1 hour
  
  def self.session_variable=(val); @@session_variable = val; end
  def self.session_variable; @@session_variable; end 
  
  def self.redis_config=(new_config); @@redis_config = new_config; end
  def self.redis_config; @@redis_config; end
  
  def self.expiry=(new_expiry); @@expiry = new_expiry; end
  def self.expiry; @@expiry; end 
  
  class Capture
    def initialize(app)
      @app = app
      @r = Redis.new(Almaz.redis_config)
    end
    
    def call(env)
      begin
        key = "almaz::#{Almaz.session_variable}::#{env['rack.session'][Almaz.session_variable]}"
        @r.push_tail(key, "#{Time.now.to_s} #{env['REQUEST_METHOD']} #{env['PATH_INFO']} #{env['QUERY_STRING']}#{env['rack.request.form_hash'].inspect}")
        @r.expire(key, Almaz.expiry)
      rescue => e
        puts "ALMAZ ERROR: #{e}"
      end
      @app.call(env)
    end
  end
  
  class View < Sinatra::Base
    
    class << self
      def user(username, password)
        @@username = username
        @@password = password
      end
    end
    
    helpers do
      def protected!
        response['WWW-Authenticate'] = %(Basic realm="Stats") and \
        throw(:halt, [401, "Not authorized\n"]) and \
        return unless authorized?
      end

      def authorized?
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [@@username, @@password]
      end
    end
    
    get '/almaz' do
      protected!
      content_type :json
      @r = Redis.new(Almaz.redis_config)
      @r.keys('*').to_json
    end
  
    get '/almaz/:id' do |id|
      protected!
      content_type :json
      @r = Redis.new(Almaz.redis_config)
      id = '' if id == 'noid'
      @r.list_range("almaz::#{Almaz.session_variable}::#{id}", 0, -1).to_json
    end
      
  end
end
