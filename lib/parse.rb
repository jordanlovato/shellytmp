module Shelly
	class Parse
		def valid_draft?(file)
			# check row length, size, and assert other qualities about file integrity
			return true
		end

		regex_map = {
			:event => {
				:analysis => /\AEvent\s#:\s[\d]{1,12}\z/,
				:match => /\AEvent\s#:\s([\d]{1,12})\z/
			}, 
			:datetime => {
				:analysis => /\ATime:\s*[\d]{1,2}\/[\d]{1,2}\/[\d]{4}\s[\d]{1,2}:[\d]{1,2}:[\d]{1,2}\s(AM|PM)\z/,
				:match => /\ATime:\s*([\d]{1,2}\/[\d]{1,2}\/[\d]{4}\s[\d]{1,2}:[\d]{1,2}:[\d]{1,2}\s(AM|PM))\z/
			},
			:players => {
				:analysis => /\APlayers:\z/,
				:match => [/\A-->\s(?!0)[\w\-]{3,20}\z/, /\A[\s]{4}(?!0)[\w\-]{3,20}\z/]
			},
			:pack => {
				:analysis => /\A[\-]{6}\s[A-Z0-9]{2,3}\s[\-]{6}\z/,
				:match => /\A[\-]{6}\s([A-Z0-9]{2,3})\s[\-]{6}\z/
			},
			:pick => {
				:analysis => /\APack\s[1-3]\spick\s[0-9]{1,2}:\z/,
				:match => [/\A-->\s([\w\s'\-,:]+)\z/, /\A\s*([\w\s'\-,:]+)\z/, /\APack\s([1-3])\spick\s([0-9]{1,2}):\z/]
			}
		}

		MATCH_EVENT = /\AEvent\s#:\s([\d]{1,12})\z/
		MATCH_DATETIME = /\ATime:\s*([\d]{1,2}\/[\d]{1,2}\/[\d]{4}\s[\d]{1,2}:[\d]{1,2}:[\d]{1,2}\s(AM|PM))\z/
		MATCH_PLAYER = /\A[\s]{4}(?!0)[\w\-]{3,20}\z/
		MATCH_PACK_BREAK = /\A[\-]{6}\s([A-Z0-9]{2,3})\s[\-]{6}\z/
		MATCH_PICK_BREAK = /\APack\s([1-3])\spick\s([0-9]{1,2}):\z/
		MATCH_NON_PLAYER_PICK = /\A\s*([\w\s'\-,:]+)\z/
		MATCH_PLAYER_PICK = /\A-->\s([\w\s'\-,:]+)\z/
		LINE_EVENT = /\AEvent\s#:\s[\d]{1,12}\z/
		LINE_DATETIME = /\ATime:\s*[\d]{1,2}\/[\d]{1,2}\/[\d]{4}\s[\d]{1,2}:[\d]{1,2}:[\d]{1,2}\s(AM|PM)\z/
		LINE_PLAYERS_DELIMIT = /\APlayers:\z/
		LINE_PACK_BREAK = /\A[\-]{6}\s[A-Z0-9]{2,3}\s[\-]{6}\z/
		LINE_PICK_BREAK = /\APack\s[1-3]\spick\s[0-9]{1,2}:\z/

		def upload_draft(file)
			output = ""
			file.each_line do |line|	
				#line = line.strip
				analyze_line(line)
				m = match_line(line)
				
				case @line_cache
				when :event
					output << "Event No. Found (" + m[1] + ")"
				when :datetime
					output << "Found Date (" + m[1] + ")"
				when :pack
					output << "Found Pack (" + m[1] + ")"
				when :player
					if (m.is_nil?)
						output << "A Player Block is Found"
					elsif (m.respond_to?('each')
						if (m.type == 0)
							output << "A Game Owner is Found (" + m_pick[1] + ")"	
						elsif (m.type == 1)
							output << "A Player is Found ("	+ m_non_pick[1] + ")"
						else
							raise 'bad match type found, requires handler'
						end
					else
						raise "bad match object type, requries handler for #{m.class}"
					end
				when :pick
					pick_set = "Pack " + m[1] + " Pick " + m[2]
					if (m.is_nil?)
						output << "A new pick-set found (" + pick_set + ")"
					elsif (m.respond_to?('each')
						if (m.type == 0)
							output << "A pick is Found (" + m_pick[1] + ") in pickset (" + pick_set + ")"
						elsif (m.type == 1)
							output << "A nonpick is Found ("	+ m_non_pick[1] + ") in pickset (" + pick_set + ")"
						else
							raise 'bad match type found, requires handler'
						end
					else
						raise "bad match object type, requries handler for #{m.class}"
					end
				end

				output << "\n"
			end

			# invalidate the cache if the duration is 0
			if (@line_cache_duration == 0) 
				@line_cache = nil
			end

			output << "newline count exceeded expectation\n" if @newline_count > 49
			return output
		end

		def match_line(line)
			re = regex_map[@line_cache][:match];	
			if ( re.kind_of?(Array) )
				if ( @line_cache_duration == 0 )
					case @line_cache
						when :player
							#player blocks are always 8 lines long
							@line_cache_duration = 8
						when :pick
							#pick block are variable length, based on a match of this specific line 
							match = line.match(re[2]);
							pick_no = match[2]
							@line_cache_duration = 16 - pick_no
					end
				else
					# process each individual line
					if ( match = line.match(re[0])
						# this line is a card that the game owner picked
						return {:match => match, :type => 0}
					elsif ( match = line.match(re[1])
						# this line is a card that the game owner did not pick
						return {:match => match, :type => 1}
					else
						raise 'No match found'
					end
				end
			else
				# return the match
				return line.match(re);
			end
		end

		def analyze_line(line)
			if (@line_cache.nil?)
				# analyze the line
				regex_map.each do |line_flag, reg_h|
					# pull analysis regex
					regex = reg_h[:analysis]		
					if (line.scan(regex).size > 0) 
						@line_cache = line_flag
						return
					end
				end
			elsif (!@line_cache.nil? && @line_cache_duration > 0)
				# decrement cache duration
				@line_cache_duration = @line_cache_duration - 1;
			end

			raise 'newline found, needs handler'
		end
	end
end
