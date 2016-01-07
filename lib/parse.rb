module Shelly
	class Parse
		def initialize
			@line_cache_duration = 0
			@line_cache = nil
			@regex_map = {
				:event => {
					:analysis => /\AEvent\s#:\s[\d]{1,12}\z/,
					:match => /\AEvent\s#:\s([\d]{1,12})\z/
				}, 
				:datetime => {
					:analysis => /\ATime:\s*[\d]{1,2}\/[\d]{1,2}\/[\d]{4}\s[\d]{1,2}:[\d]{1,2}:[\d]{1,2}\s(AM|PM)\z/,
					:match => /\ATime:\s*([\d]{1,2}\/[\d]{1,2}\/[\d]{4}\s[\d]{1,2}:[\d]{1,2}:[\d]{1,2}\s(AM|PM))\z/
				},
				:player => {
					:analysis => /\APlayers:\z/,
					:match => [/\A-->\s((?!0)[\w\-]{3,20})\z/, /\A[\s]{4}((?!0)[\w\-]{3,20})\z/]
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
		end

		def valid_draft?(file)
			# check row length, size, and assert other qualities about file integrity
			return true
		end

		def upload_draft(file)
			output = ""
			file.each_line do |line|	
				line = line.rstrip
				analyze_line(line)
				m = match_line(line)
				puts @line_cache_duration
				puts m.inspect
				
				case @line_cache
				when :event
					output << "Event No. Found (" + m[1] + ")"
				when :datetime
					output << "Found Date (" + m[1] + ")"
				when :pack
					output << "Found Pack (" + m[1] + ")"
				when :player
					if (m.nil?)
						output << "A Player Block is Found"
					elsif ( m.respond_to?('each') )
						if (m[:type] == 0)
							output << "A Game Owner is Found (" + m[:match][1] + ")"	
						elsif (m[:type] == 1)
							output << "A Player is Found ("	+ m[:match][1] + ")"
						else
							raise 'bad match type found, requires handler'
						end
					else
						raise "bad match object type, requries handler for #{m.class}"
					end
				when :pick
					pick_set = "Pack " + m[:match][1] + " Pick " + m[:match][2]
					if (m.nil?)
						output << "A new pick-set found (" + pick_set + ")"
					elsif ( m.respond_to?('each') )
						if (m[:type] == 0)
							output << "A pick is Found (" + m[:match][1] + ") in pickset (" + pick_set + ")"
						elsif (m[:type] == 1)
							output << "A nonpick is Found ("	+ m[:match][1] + ") in pickset (" + pick_set + ")"
						else
							raise 'bad match type found, requires handler'
						end
					else
						raise "bad match object type, requries handler for #{m.class}"
					end
				when :whitespace
					output << "\r\n"
				end
				output << "\n"
			end

			if (@line_cache_duration == 1) 
				@line_cache = nil
				@line_cache_duration == 0
			end

			output << "newline count exceeded expectation\n" if @newline_count > 49
			return output
		end

		def match_line(line)
			re = @regex_map[@line_cache][:match]

			if ( re.kind_of?(Array) )
				if ( @line_cache_duration == 0 )
					case @line_cache
						when :player
							#player blocks are always 8 lines long
							@line_cache_duration = 9
							return nil
						when :pick
							#pick block are variable length, based on a match of this specific line 
							match = line.match(re[2])
							pick_no = match[2]
							@line_cache_duration = 17 - pick_no
							return nil
					end
				else
					# process each individual line
					if ( match = line.match(re[0]) )
						# this line is a card that the game owner picked
						return {:match => match, :type => 0}
					elsif ( match = line.match(re[1]) )
						# this line is a card that the game owner did not pick
						return {:match => match, :type => 1}
					else
						raise 'No match found'
					end
				end
			else
				# return the match
				return line.match(re)
			end
		end

		def analyze_line(line)
			if (@line_cache.nil?)
				# analyze the line
				@regex_map.each do |line_flag, reg_h|
					# pull analysis regex
					regex = reg_h[:analysis]		
					if (line.scan(regex).size > 0) 
						@line_cache = line_flag
						return
					end
				end

				# we have whitespace
				@line_cache = :whitespace
			elsif (!@line_cache.nil? && @line_cache_duration > 0)
				# decrement cache duration
				@line_cache_duration = @line_cache_duration - 1
			end
		end
	end
end
