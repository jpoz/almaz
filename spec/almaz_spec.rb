require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

require 'redis/raketasks'
require 'rack/test'

describe Almaz do
  before(:each) do
    Almaz.session_variable = :user
    Almaz.redis_config = {:db => 15}
  end

  describe Almaz::Capture do
    include Rack::Test::Methods
 
    def app
      use Rack::Session::Cookie, :key => '_max_project_session'
      use Almaz::Capture
      use ExampleSinatraApp
      Sinatra::Application
    end
  
    describe "with session's user id" do
  
      before(:each) do
        session_info = {:user => 1}
        rack_mock_session.set_cookie("_max_project_session=#{[Marshal.dump(session_info)].pack("m*")}")
      end

      it "should capture the request path under the session_variable" do
        get '/awesome/controller'
        @db.list_range('almaz::user::1',0,-1).first.should include('/awesome/controller')
      end
    
      it "should capture the request query params under the session_variable" do
        get '/awesome/controller?whos=yourdaddy&what=doeshedo'
        @db.list_range('almaz::user::1',0,-1).first.should include('whos=yourdaddy&what=doeshedo')
      end

      it "should capture the request method params under the session_variable" do
        get '/awesome/controller'
        @db.list_range('almaz::user::1',0,-1).first.should include('GET')
      end

      it "should capture the post params under the session_variable" do
        post '/awesome/controller', :didyouknow => 'thatyouremyhero'
        @db.list_range('almaz::user::1',0,-1).first.should include("{\"didyouknow\"=>\"thatyouremyhero\"}")
      end
      
      it "should record a timestamp on each request" do
        Timecop.freeze(Date.today + 30) do        
          post '/awesome/controller', :didyouknow => 'thatyouremyhero'
          @db.list_range('almaz::user::1',0,-1).first.should include(Time.now.to_s)
        end
      end
      
      it "should not fail if there is no redis server" do
        @db.quit
        RedisRunner.stop
        get '/awesome/controller'
        result = RedisRunner.start_detached
        sleep 1
        @db = Redis.new(Almaz.redis_config)
        
        last_response.should be_successful
      end

    end
  
  end

  describe Almaz::View do
    include Rack::Test::Methods
  
    def app
      use Almaz::View
      Sinatra::Application
    end
  
    before(:each) do
      @requests = ['GET /awesome/controller limit=2', 'POST /awesome/controller didyouknow=thatyouremyhero', 'GET /awesome/controller']
      @requests.each do |r|
        @db.push_tail('almaz::user::1',r)
      end
      Almaz::View.user('andrew','iscool')
    end
  
    it "should respond to /almaz/:id" do
      get '/almaz/1', {}, {'HTTP_AUTHORIZATION' => encode_credentials('andrew', 'iscool')}
      last_response.should be_successful
    end
    
    it "should respond to /almaz" do
      get '/almaz', {}, {'HTTP_AUTHORIZATION' => encode_credentials('andrew', 'iscool')}
      last_response.should be_successful
    end
  
    it 'should deny bad people away from show action' do
      get '/almaz/1', {}, {'HTTP_AUTHORIZATION' => encode_credentials('james', 'goaway')}
      last_response.should_not be_successful
    end
    
    it 'should deny bad people away from index action' do
      get '/almaz', {}, {'HTTP_AUTHORIZATION' => encode_credentials('james', 'goaway')}
      last_response.should_not be_successful
    end
  
    describe 'with correct authentication' do
      it "should return the list of request for the given user in json" do
        get '/almaz/1', {}, {'HTTP_AUTHORIZATION' => encode_credentials('andrew', 'iscool')}
        last_response.body.should == @requests.to_json
        last_response.content_type.should == 'application/json'
      end
      
      it 'should return the list of request for those without a value for the session_varible if noid is given' do
        r = 'GET /login'
        @db.push_tail('almaz::user::',r)
        get '/almaz/noid', {}, {'HTTP_AUTHORIZATION' => encode_credentials('andrew', 'iscool')}
        last_response.body.should include(r.to_json)
      end
      
      it 'should return the list valid keys' do
        @db.push_tail('almaz::user::awesome','GET /butter')
        get '/almaz', {}, {'HTTP_AUTHORIZATION' => encode_credentials('andrew', 'iscool')}
        last_response.body.should include('almaz::user::1'.to_json)
        last_response.body.should include('almaz::user::'.to_json)
        last_response.body.should include('almaz::user::awesome'.to_json)
      end
    end
  
  end

end
