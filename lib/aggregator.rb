# coding: utf-8
# This program tries to find paterns on a website that match table like structures with financial
# data. Its a work in progress but getting along nicely.
#
# It requires Ruby version 1.9.2
#
# Author:: Timon Vonk (mailto:timonv@gmail.com)
# Copyright:: Copyright (c) 2010 delaagsterekening.nl
# License:: Distributes under the same terms as Ruby

require 'nokogiri'
require 'net/smtp'
require 'net/http'
require 'open4'
#require 'iconv'
require 'pp'
require 'mechanize'

# Require rest of gem
                 
#+TODO+::  Cleanup
LOCAL = true
ROOT = LOCAL ? "#{Dir.home}/log" : "#{Dir.home}/site_checker/log"

# Contains classes for data aggregation of financial data
module CheckTarives
	# This is the main class that contains methods for patern matching
	class Aggregator
		# Creates a new aggregator object
		# +TODO+::  Pass in data for nicer handling
		def initialize(url,name,search_string = nil)
			@agent = Mechanize.new
			@agent.user_agent_alias = "Mac FireFox"
			@agent.read_timeout = 5.0 # 5 seconds time out

			@page[:name] = name
			@page[:url] = url
			@page[:search_string] = search_string
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
		# @page[:search_string] = "string to search page with using xpath contains"
		# +TODO+::  Needs proper error handling outside method
		def check_site
			page = @agent.get(@page[:url])
			raise "got redirected on #{@page[:name]}" if redirect?

			doc = Nokogiri::HTML(page.parser.to_s)
			nodes_with_euros = doc.search("//text()[contains(.,'€')]")
			containers_array = []
			raise "no euros found #{@page[:name]}" if nodes_with_euros == []

			# Previous version was with ruby, now xpath, less code. 
			containers_array = nodes_with_euros.collect { |node| node.ancestors("//table | //div").first } unless @page[:search_string]

			if @page[:search_string]
				#remove escapes
				@page[:search_string].gsub!(/\\/) { ''}
				containers_array << doc.search("//text()[contains(.,#{@page[:search_string]})]").first
			end

			#Nodeset is an array, but doesn't act like on, really annoying.
			containers_nodeset = Nokogiri::XML::NodeSet.new(doc)
			containers_freqs = containers_array.inject(Hash.new(0)) { |h,v| h[v] += 1; h}
			
			# Refactored from double block
			containers_nodeset = containers_freqs.collect { |node,freq| freq > 1 ? node : nil }
			containers_nodeset.uniq!
			raise "no hits found in #{@page[:name]}" if containers_nodeset.empty?

			write_to_file(containers_nodeset)
			
			#overwrite the old content with the new one
		end

		# Checks if given uri is a redirect. Should work directly on an instance variable
		def redirect?
			http_response = Net::HTTP.get_response(URI.parse(@page[:url]))
			http_response == Net::HTTPRedirection
		end

		# Writes site data to file. Needs refactoring
		def write_to_file(data)
			if File.exists?(File.join(ROOT, "tariffs_" + @page[:name]))
				diff = ""
				status = Open4::popen4("diff #{File.join(ROOT, "tariffs_" + @page[:name])} -") do |pid, stdin, stdout, stderr|
					stdin.puts data
					stdin.close
					diff = stdout.read
				end
				#sent mail if content is different
				if status != 0
					write "change detected."
					notify_changed_site(url, diff)
					pp "Data changed on #{@page[:name]}"
				end
			end
		end
		File.open(File.join(ROOT, "tariffs_" + @page[:name]), "w") do |f|
				f.puts containers_nodeset
		end
	end
end
