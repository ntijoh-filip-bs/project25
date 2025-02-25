require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/activerecord'
require 'slim'
require 'sinatra/flash'

set :database, { adapter: 'sqlite3', database: 'db/database.db' }

enable :sessions

get '/' do
  slim :index
end

get '/register' do
  slim :register
end

get '/login' do
  slim :login
end

get '/logout' do
  session.clear
  flash[:success] = "Logged out"
  redirect '/'
end