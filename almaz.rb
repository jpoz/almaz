require 'rubygems'
require 'sinatra'
require 'redis'

class Almaz
  
  class Capture
    def initialize(app)
      @app = app
    end
    
    def call(env)
      puts env.inspect
      
      r = Redis.new
      
      request_num = r.incr("almaz::requests")      
      r["almaz::path::#{request_num}"] = env['REQUEST_PATH']
      r["almaz::query::#{request_num}"] = env['QUERY_STRING']
      
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
  
    get '/stats' do
      protected!
      @r = Redis.new
      @requests = @r['almaz::requests']
      haml :stats
    end
    
    use_in_file_templates!
  
  end
end

__END__

@@ stats

!!!
%html{ :xmlns => "http://www.w3.org/1999/xhtml", :"xml:lang" =>"en", :lang =>"en" }
  %head
    %title
      Statistics
  %body{:style => 'background: #dadada'}
    #content{:style => 'width: 800px; margin: 100px auto; background: #FFF; padding: 10px; border: 1px solid #BABABA;'}
      %table
        %tr
          %td
            Requests:
          %td
            = @requests
        - @requests.to_i.downto(0) do |i|
          %tr
            %td{:style => 'vertical-align:top'}
              Path:
            %td
              = @r["almaz::path::#{i}"]
            %td{:style => 'vertical-align:top'}
              Query:
            %td
              = @r["almaz::query::#{i}"]
