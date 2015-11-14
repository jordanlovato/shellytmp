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
			output = upload_draft file
		end
	end
	haml :upload, :locals => {:output => output}
end

def valid_draft?(file)
	# check row length, size, and assert other qualities about file integrity
	return true
end

MATCH_EVENT = /\AEvent\s#:\s([\d]{1,12})\z/
MATCH_DATETIME = /\ATime:\s*([\d]{1,2}\/[\d]{1,2}\/[\d]{4}\s[\d]{1,2}:[\d]{1,2}:[\d]{1,2}\s(AM|PM))\z/
MATCH_PACK_BREAK = /\A[\-]{6}\s([A-Z0-9]{3})\s[\-]{6}\z/
MATCH_PICK_BREAK = /\APack\s([1-3])\spick\s([0-9]{1,2}):\z/
MATCH_NON_PLAYER_PICK = /\A\s*([\w\s]+)\z/
MATCH_PLAYER_PICK = /\A-->\s([\w\s]+)\z/

:line_event
:line_date_time
:line_pack_break
:line_pick_break
:line_players_delimit
:line_misc

def upload_draft(file)
	output = ""
	push_next = 0
	analysis_flag = nil
	pick_set = ""
	@newline_count = 0

	#add draft to mongo
	file.each_line do |line|	
		line = line.strip
		sort = nil
		sort = analyze_line line unless push_next > 0
		analysis_flag = sort unless sort.nil?

		case analysis_flag
		when :line_event
			m = line.match(MATCH_EVENT)
			output << "Event No. Found (" + m[1] + ")"
		when :line_date_time
			m = line.match(MATCH_DATETIME)
			output << "Found Date (" + m[1] + ")"
		when :line_pack_break
			m = line.match(MATCH_PACK_BREAK)
			output << "Found Pack (" + m[1] + ")"
		when :line_players_delimit
			push_next = 9 unless push_next > 0
			
			if ( m_non_pick = line.match(MATCH_NON_PLAYER_PICK) )
				output << "A Player is Found ("	+ m_non_pick[1] + ")"
			elsif ( m_pick = line.match(MATCH_PLAYER_PICK) )
				output << "A Game Owner is Found (" + m_pick[1] + ")"	
			end	

			push_next = push_next - 1

		when :line_pick_break
			unless push_next > 0
				m_pack_pick = line.match(MATCH_PICK_BREAK)
				pick_set = "Pack " + m_pack_pick[1] + " Pick " + m_pack_pick[2]
				output << "A new pick-set found (" + pick_set + ")"
				push_next = 17 - m_pack_pick[2].to_i
			end
					
			if ( m_non_pick = line.match(MATCH_NON_PLAYER_PICK) )
				output << "A nonpick is Found ("	+ m_non_pick[1] + ") in pickset (" + pick_set + ")"
			elsif ( m_pick = line.match(MATCH_PLAYER_PICK) )
				output << "A pick is Found (" + m_pick[1] + ") in pickset (" + pick_set + ")"
			end

			push_next = push_next - 1 
		when :line_misc
		end
		
		output << "\n"
	end

	return output
end

LINE_EVENT = /\AEvent\s#:\s[\d]{1,12}\z/
LINE_DATETIME = /\ATime:\s*[\d]{1,2}\/[\d]{1,2}\/[\d]{4}\s[\d]{1,2}:[\d]{1,2}:[\d]{1,2}\s(AM|PM)\z/
LINE_PLAYERS_DELIMIT = /\APlayers:\z/
LINE_PACK_BREAK = /\A[\-]{6}\s[A-Z0-9]{3}\s[\-]{6}\z/
LINE_PICK_BREAK = /\APack\s[1-3]\spick\s[0-9]{1,2}:\z/
	
def analyze_line(line)
	# assert the validity of each line. Draft files are computer 
	# generated, so if we get this far we can assert certain 
	# qualities about each line.
	if (line.scan(LINE_EVENT).size > 0) 
		return :line_event
	elsif (line.scan(LINE_DATETIME).size > 0)
		return :line_date_time
	elsif (line.scan(LINE_PLAYERS_DELIMIT).size > 0)
		return :line_players_delimit
	elsif (line.scan(LINE_PACK_BREAK).size > 0)
		return :line_pack_break
	elsif (line.scan(LINE_PICK_BREAK).size > 0)
		return :line_pick_break
	else
		@newline_count += 1
		return :line_misc	
	end	
end
