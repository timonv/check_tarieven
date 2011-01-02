require 'csv'


	# Simple class that maps the csv data in a pretty way to an array of hashes
	# Because its a File it should NEVER be called multiple times at the same time. CSV is just lightweight and fast compared to a db.
module CheckTarives
	module Data
		# Returns all lines in an array of hashes
		def self.get_pretty
			data = []
			CSV.foreach("../data/data.csv") do |line|
				data << { :name => line[1], :url => line[0], :search_string => line[2] }
			end
			data
		end

		# Removes a single line
		def self.remove_line
		end

		# Gets a single line
		def self.get_line
		end

	end
end
