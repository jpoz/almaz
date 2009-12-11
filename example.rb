require 'rubygems'
require 'sinatra'
require 'lib/almaz'

enable :sessions

use Almaz::Capture # used to capture all requests
use Almaz::View # add /stats

Almaz.session_variable = 'name'
Almaz.redis_config = {:db => 0, :host => 'localhost', :port => 6379}

Almaz::View.user('jpoz','pass') # set your username and password here for the /stats area

get '/' do
  'Wazz up party people. Welcome to my site. Do what ever you want no body is watching you.'
end

get '/mynameis/:name' do |name|
  session['name'] = name
  "Okay your name is now #{name}"
end

not_found do
  '404'
end

error do
  'Sorry there was a nasty error - ' + env['sinatra.error']
end