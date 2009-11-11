require 'rubygems'
require 'sinatra'
require 'almaz'

use Almaz::Capture # used to capture all requests
use Almaz::View # add /stats

Almaz::View.user('jpoz','pass') # set your username and password here for the /stats area

get '/' do
  'Wazz up party people. Welcome to my site. Do what ever you want no body is watching you.'
end

get '/jpoz' do
  'WOrrd'
end

not_found do
  '404'
end

error do
  'Sorry there was a nasty error - ' + env['sinatra.error']
end