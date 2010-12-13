# encoding: utf-8
require 'rubygems'
require 'nokogiri'
# require 'open-uri'
require 'net/smtp'
# require 'net/http'
# require 'net/https'
require 'open4'
require 'iconv'
require 'pp'
require 'mechanize'
require './data.rb'

                 
#TODO: Cleanup
LOCAL = true
ROOT = LOCAL ? "/home/timonv/log" : "/home/harm/site_checker/log"

class Aggregator
	def write(message)
		@logfile.puts Time.now.strftime("%d-%m-%y %H:%M ") << message
	end

	def initialize
		@logfile      = File.open "#{ROOT}/site_checker.log", 'a'
		@logfile.sync = true

		@ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
		@agent = Mechanize.new
		@agent.user_agent_alias = "Mac FireFox"
		@agent.read_timeout = 5.0 # 5 seconds time out
	end

	# Set some email addresses for better debugging
	#
	def handle_exception(e)
		write "Exception caught: #{e}"
		write "Backtrace: #{e.backtrace}"
		Net::SMTP.start('localhost') do |smtp|
		 smtp.send_message("Something went wrong!\n Error:\n#{e}\nStacktrace:\n#{pp e.backtrace.collect{|t|@ic.iconv(t)}}", 'inspector_tariff@delaagsterekening.nl', 'harm@delaagsterekening.nl')
		end unless LOCAL
	end

	def notify_changed_site(changed_site, diff)
			msgstr = <<-END_OF_MESSAGE
		From: Inspector Tariff <inspector_tariff@delaagsterekening.nl>
		To: Harm Aarts <harm@delaagsterekening.nl>
		Subject: Tariffs of #{changed_site[1]} changed

		Do something! #{changed_site[0]}.\n
		Diff:
		#{@ic.iconv(diff)}
		END_OF_MESSAGE
		Net::SMTP.start('localhost') do |smtp|
			smtp.send_message(msgstr, 'inspector_tariff@delaagsterekening.nl', 'harm@delaagsterekening.nl')
		end unless LOCAL
	end

	def check_site(url, search_string = nil)
		begin
			page = @agent.get(url[0])
			# notify_changed_site(url, "URL target redirected") if redirect?(http, uri)
			# response, body = http.get(uri.path)
			doc = Nokogiri::HTML(page.parser.to_s)
			nodes_with_euros = doc.search("//text()[contains(.,'€')]")
			containers_array = []
			raise Exception,  "no_euros_found #{url[1]}" if nodes_with_euros == []

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
			containers_array.uniq!
			containers_array.each do |node|
				# If the container got hit > 1, its possibly tabular, otherwise, ditch it.
				# grep is slow, but much easier on the eyes than the inject variant
				if containers_freqs[node] > 1
					containers_nodeset << node
				end
				containers_nodeset << node if search_string
			end
			raise "No hits found in #{url[1]}" if containers_nodeset.empty?

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
			pp "#{e} on #{url[1]}"
		rescue Exception => e
			pp "#{e.to_s}"
		else
			pp "No errors on: #{url[1]}"
		end

	end

	def redirect?(http, uri)
		resp = http.get(uri.path)
		return true if resp.code != "200"
		return false
	end
end

def test_kpn
	agg = Aggregator.new
	pp agg.check_site(KPN)
end

def test_gsm_arena
	agg = Aggregator.new
	agg.check_site([GSMARENA[0],GSMARENA[1]],GSMARENA[2])
end

def do_all
	all_data = []
	agg = Aggregator.new
	File.open("./data.rb") do |file|
		file.each_line do |line|
			line.to_s.sub!(/^\w+\s*=/,"")
			all_data << eval(line)
		end
	end
	all_data.each do |data|
		if data
			data[2] ? agg.check_site([data[0],data[1]],data[2]) : agg.check_site(data)
		end
	end
	return true
end
