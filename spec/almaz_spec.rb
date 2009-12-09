require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

require 'redis/raketasks'
require 'rack/test'
 
describe Almaz::Capture do
  include Rack::Test::Methods
 
  def app
    Rack::Session::Cookie.new(
      Almaz::Capture.new(
        Sinatra::Application), :key => '_max_project_session')
  end
  
  describe "with session's user id" do
  
    before(:each) do
      Almaz::Capture.session_variable = :user
      Almaz::Capture.redis_db = 15
      
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
      @db.list_range('almaz::user::1',0,-1).first.should include("didyouknow=thatyouremyhero")
    end
    
    it "should rewind the post params" do
      pending 'this passes even if you dont have rewind in there'
      post '/awesome/controller', :didyouknow => 'thatyouremyhero'
      rack_mock_session.last_request.env['rack.input'].read.should == "didyouknow=thatyouremyhero"
    end

  end

  
end
