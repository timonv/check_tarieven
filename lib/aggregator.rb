# coding: utf-8
# This program tries to find paterns on a website that match table like structures with financial
# data. Its a work in progress but getting along nicely.
#
# It requires Ruby version 1.9.2
#
# Author:: Timon Vonk (mailto:timonv@gmail.com)
# Copyright:: Copyright (c) 2010 delaagsterekening.nl
# License:: Distributes under the same terms as Ruby
#
require 'nokogiri'
# require 'open-uri'
require 'net/smtp'
# require 'net/http'
# require 'net/https'
require 'open4'
require 'iconv'
require 'pp'
require 'mechanize'

# Require rest of gem
# Data.rb is being remodelled to csv
#require_relative '/data.rb'

                 
#+TODO+::  Cleanup
LOCAL = true
ROOT = LOCAL ? "#{Doc.home}/log" : "#{Doc.home}/site_checker/log"

# Contains classes for data aggregation of financial data
module CheckTarives
	# This is the main class that contains methods for patern matching
	class Aggregator
		def write(message)
			@logfile.puts Time.now.strftime("%d-%m-%y %H:%M ") << message
		end

		# Creates a new aggregator object
		# +TODO+::  Pass in data for nicer handling
		def initialize
			# Logger to be implemented
			#@logfile      = File.open "#{ROOT}/site_checker.log", 'a'
			#@logfile.sync = true

			@ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
			@agent = Mechanize.new
			@agent.user_agent_alias = "Mac FireFox"
			@agent.read_timeout = 5.0 # 5 seconds time out
		end

		# To be refactored
		#
		#def handle_exception(e)
		#	write "Exception caught: #{e}"
		#	write "Backtrace: #{e.backtrace}"
		#	Net::SMTP.start('localhost') do |smtp|
		#	 smtp.send_message("Something went wrong!\n Error:\n#{e}\nStacktrace:\n#{pp e.backtrace.collect{|t|@ic.iconv(t)}}", 'inspector_tariff@delaagsterekening.nl', 'harm@delaagsterekening.nl')
		#	end unless LOCAL
		#end

		#def notify_changed_site(changed_site, diff)
		#		msgstr = <<-END_OF_MESSAGE
		#	From: Inspector Tariff <inspector_tariff@delaagsterekening.nl>
		#	To: Harm Aarts <harm@delaagsterekening.nl>
		#	Subject: Tariffs of #{changed_site[1]} changed

		#	Do something! #{changed_site[0]}.\n
		#	Diff:
		#	#{@ic.iconv(diff)}
		#	END_OF_MESSAGE
		#	Net::SMTP.start('localhost') do |smtp|
		#		smtp.send_message(msgstr, 'inspector_tariff@delaagsterekening.nl', 'harm@delaagsterekening.nl')
		#	end unless LOCAL
		#end

		# Checks a website for financial data
		# url = [ "url", "name" ]
		# search_string = "string to search page with using xpath contains"
		# +TODO+::  Clean up, should take only a search string and options
		# +TODO+::  Needs some refactoring
		# +TODO+::  Needs proper error handling outside method
		def check_site(url, search_string = nil)
			begin
				page = @agent.get(url[0])
				# Couldnt get this to work properly. redirect? function should work, but doesn't. This works in java version, not in ruby version :/
				# raise "got redirected on #{url[1]}" if @agent.response_code =~ /30\d/

				# notify_changed_site(url, "URL target redirected") if redirect?(http, uri)
				# response, body = http.get(uri.path)
				doc = Nokogiri::HTML(page.parser.to_s)
				nodes_with_euros = doc.search("//text()[contains(.,'€')]")
				containers_array = []
				raise "no euros found #{url[1]}" if nodes_with_euros == []

				# Previous version was with ruby, now xpath, less code. 
				nodes_with_euros.each do |node|
					candidate = node.ancestors("//table | //div").first
					containers_array << candidate unless candidate == nil
				end unless search_string

				if search_string
					#remove escapes
					search_string.gsub!(/\\/) { ''}
					containers_array << doc.search("//text()[contains(.,#{search_string})]").first
				end

				#Nodeset is an array, but doesn't act like on, really annoying.
				containers_nodeset = Nokogiri::XML::NodeSet.new(doc)
				containers_freqs = containers_array.inject(Hash.new(0)) { |h,v| h[v] += 1; h}
				
				# Refactored from double block
				containers_nodeset = containers_freqs.collect { |node,freq| freq > 1 ? node : nil }
				containers_nodeset.uniq!
				# pp containers_nodeset
				raise "no hits found in #{url[1]}" if containers_nodeset.empty?

				#pp nodes_with_euros
				#pp containers_array
				#pp containers_nodeset

				#check if content is different
				if File.exists?(File.join(ROOT, "tariffs_" + url[1]))
					diff = ""
					status = Open4::popen4("diff #{File.join(ROOT, "tariffs_" + url[1])} -") do |pid, stdin, stdout, stderr|
						stdin.puts containers_nodeset
						stdin.close
						diff = stdout.read
					end
					#sent mail if content is different
					if status != 0
						write "change detected."
						notify_changed_site(url, diff)
						pp "Data changed on #{url[1]}"
					end
				end
				
				#overwrite the old content with the new one
				File.open(File.join(ROOT, "tariffs_" + url[1]), "w") do |f|
					f.puts containers_nodeset
				end

				return containers_nodeset
			rescue Timeout::Error => e
				pp e.message
				pp e.backtrace
				# Mailings should go here
			rescue Exception => e
				pp e.message
				pp e.backtrace
				# Mailing should go here
			else
				pp "No errors on: #{url[1]}"
			end

		end

		# Checks if given uri is a redirect. Should work directly on an instance variable
		# +TODO+::  Is broken
		def redirect?(uri)
			http_response = Net::HTTP.get_response(URI.parse(uri))
			http_response == Net::HTTPRedirection
		end
	end
end

#def do_all
#		all_data = []
#		agg = Aggregator.new
#		File.open("./data.rb") do |file|
#			file.each_line do |line|
#				line.to_s.sub!(/^\w+\s*=/,"")
#				all_data << eval(line)
#			end
#		end
#		all_data.each do |data|
#			if data
#				data[2] ? agg.check_site([data[0],data[1]],data[2]) : agg.check_site(data)
#			end
#		end
#		return true
#end
