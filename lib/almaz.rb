require 'rubygems'
require 'sinatra'
require 'redis'
require 'json'
require 'cgi'


class Almaz
  @@session_variable = 'session_id'
  @@redis_db = 0
  
  def self.session_variable=(val)
    @@session_variable = val
  end
  def self.session_variable; @@session_variable; end 
  
  def self.redis_db=(val)
    @@redis_db = val
  end
  def self.redis_db; @@redis_db; end 
  
  class Capture
    def initialize(app)
      @app = app
      @r = Redis.new(:db => Almaz.redis_db)
    end
    
    def call(env)
      @r.push_tail("almaz::#{Almaz.session_variable}::#{env['rack.session'][Almaz.session_variable]}", "#{Time.now.to_s} #{env['REQUEST_METHOD']} #{env['PATH_INFO']} #{env['QUERY_STRING']}#{CGI.unescape(env['rack.input'].read)}") rescue nil
      env['rack.input'].rewind
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
      @r = Redis.new(:db => Almaz.redis_db)
      @r.keys('*').to_json
    end
  
    get '/almaz/:id' do |id|
      protected!
      content_type :json
      @r = Redis.new(:db => Almaz.redis_db)
      id = '' if id == 'noid'
      @r.list_range("almaz::#{Almaz.session_variable}::#{id}", 0, -1).to_json
    end
      
  end
end
