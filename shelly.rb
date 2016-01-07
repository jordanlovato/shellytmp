require 'rubygems'
require 'sinatra'
require 'mongo'
require 'json/ext'
require_relative 'lib/parse'

set :port, 3000
set :bind, '0.0.0.0'
set :haml, :format => :html5

configure do
	db = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'test')
	set :mongo_db, db[:test]
end

get '/upload' do
	haml :upload
end

post '/upload' do
	output = ""
	parser = Shelly::Parse.new
	logfile = File.open(params[:draft_log][:tempfile].path) do |file|
		if (parser.valid_draft? file)
			output = parser.upload_draft file
		end
	end
	haml :upload, :locals => {:output => output}
end

