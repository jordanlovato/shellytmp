require 'rubygems'
require 'sinatra'
require 'mongo'
require 'json/ext'

set :port, 3000
set :bind, '0.0.0.0'
set :haml, :format => :html5

configure do
	db = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'test')
	set :mongo_db, db[:test]
end

get '/new_document/?' do
	haml :new_document
end

post '/new_document/?' do
	content_type :json
	db = settings.mongo_db
	result = db.insert_one params
	db.find(:id => result.inserted_id).to_a.first.to_json
end

get '/collection/:first_name' do
	content_type :json
	document = settings.mongo_db.find(:first_name => params[:first_name]).to_a.first.to_json
end

get '/' do
	haml :index
end

get '/upload' do
	haml :upload
end

post '/upload' do
	output = ""
	logfile = File.open(params[:draft_log][:tempfile].path) do |file|
		if valid_draft? file
			output = Shelly::Parse.upload_draft file
		end
	end
	haml :upload, :locals => {:output => output}
end

