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

HI_MET_TOESTEL          = ["http://www.hi.nl/Productinfo/Abonnement/Tarieven-Hi-Abonnement.htm", "hi_met_toestel"]
HI_SIM_ONLY             = ["http://www.hi.nl/Productinfo/Hi-Simonly-abonnement.htm", "hi_sim_only"]
T_MOBILE_RELAX          = ["http://www.t-mobile.nl/mobiel-abonnement/tarieven", "t_mobile_relax"]
T_MOBILE_RELAX_ONLINE   = ["http://www.t-mobile.nl/mobiel-abonnement/tarieven", "t_mobile_relax_online"]
T_MOBILE_RELAX_SIM_ONLY = ["http://www.t-mobile.nl/mobiel-abonnement/tarieven", "t_mobile_relax_sim_only"]
T_MOBILE_VOORDEELSIM    = ["http://www.t-mobile.nl/mobiel-abonnement/tarieven", "t_mobile_voordeelsim"]
T_MOBILE_IPHONE         = ["http://www.t-mobile.nl/mobiel-abonnement/tarieven", "t_mobile_iphone"]
VODAFONE_BELLEN         = ["http://www.vodafone.nl/mobiel_bellen/abonnementen/abonnementen_met_toestel/bellen/", "vodafone_bellen"]
VODAFONE_BELLEN_SMS     = ["http://www.vodafone.nl/mobiel_bellen/abonnementen/abonnementen_met_toestel/bel_sms/", "vodafone_bellen_sms"]
VODAFONE_BELLEN_SMS_WEB = ["http://www.vodafone.nl/mobiel_bellen/abonnementen/abonnementen_met_toestel/bel_sms_web", "vodafone_bellen_sms_web"]
VODAFONE_SCHERP         = ["http://www.vodafone.nl/mobiel_bellen/abonnementen/sim_only_abonnement/vodafone_scherp", "vodafone_scherp"]
VODAFONE_BELLEN_SMS_SO  = ["http://www.vodafone.nl/mobiel_bellen/abonnementen/sim_only_abonnement/bel_sms/tarieven", "vodafone_bellen_sms_so"]
VODAFONE_BELLEN_SMS_WEB_SO = ["http://www.vodafone.nl/mobiel_bellen/abonnementen/sim_only_abonnement/bel_sms_web/tarieven", "vodafone_bellen_sms_web_so"]
KPN                     = ["http://www.kpn.com/is-bin/INTERSHOP.enfinity/WFS/KPN-B2C-Site/nl_NL/-/EUR/DDTProductDetail-ShowSubscriptionDL", "kpn"]
KPN_SIM_ONLY            = ["http://www.kpn.com/prive/mobiel/tarieven/Abonnementen.htm", "kpn_sim_only"]
TELFORT_MET_TOESTEL     = ["http://shop.telfort.nl/abonnement/informatie/", "telfort_met_toestel"]
TELFORT_UNLIMITED       = ["http://shop.telfort.nl/sim-only/informatie/unlimited/", "telfort_unlimited"]
TELFORT_SIM_ONLY        = ["http://shop.telfort.nl/sim-only/informatie/", "telfort_sim_only"]
BEN                     = ["http://www.ben.nl/abonnementen", "ben"]
                        
GSMARENA                = ["http://www.gsmarena.com/", "gsmarena"]
ESATO                   = ["http://www.esato.com/phones/", "esato"]
                        
INLOG_TMOBILE           = ["http://www.t-mobile.nl/my-t-mobile", "inlog_tmobile"]
INLOG_KPN               = ["http://www.kpn.com/inloggen.htm", "inlog_kpn"]
INLOG_HI                = ["http://www.hi.nl/", "inlog_hi"]
INLOG_VODAFONE          = ["https://my.vodafone.nl/prive/my_vodafone?errormessage=&errorcode=", "inlog_vodafone"]
INLOG_TELFORT           = ["https://www.telfort.nl/mijntelfort/mobiel/inloggen/", "inlog_telfort"]
                           
#TODO: Cleanup
LOCAL = true
ROOT = LOCAL ? "/home/timonv/log" : "/home/harm/site_checker/log"

@logfile      = File.open "#{ROOT}/site_checker.log", 'a'
@logfile.sync = true

@ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
@agent = Mechanize.new
@agent.user_agent_alias = "Mac FireFox"

def write(message)
  @logfile.puts Time.now.strftime("%d-%m-%y %H:%M ") << message
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
  msgstr = <<END_OF_MESSAGE
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

def find_parent_container(node, depth)
	if node.parent.class == Nokogiri::XML::Element
		if node.parent
			if node.parent.name == 'table' or node.parent.name == 'div'
				return node.parent
			elsif depth > 0
				find_parent_container(node.parent, depth - 1)
			end
		else
			return false
		end
	else
		return false
	end
end

def check_site(site_arr)
  page = @agent.get(site_arr[0])
  # uri  = URI.parse(site_arr[0])
  # http = Net::HTTP.new(uri.host, uri.port)
  # if uri.scheme == "https"
  #   http.use_ssl = true
  #   http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  # end
  # 
  # notify_changed_site(site_arr, "URL target redirected") if redirect?(http, uri)
  # response, body = http.get(uri.path)
  doc = Nokogiri::HTML(page.parser.to_s)
  #elms = yield(doc)
  # puts elms.to_s if LOCAL
  #raise "Elements is empty #{site_arr[1]}!\nSite:#{site_arr[0]}\nDocument:\n#{@ic.iconv(doc.to_s)}" if elms.empty?
  #new_content = elms.first.inner_html
	nodes_with_euros = doc.search("//text()[contains(.,'€')]")
	#pp nodes_with_euros
	containers = []
	nodes_with_euros.each do |node|
		parent_container = find_parent_container(node, 5)
		parent_container ? containers << parent_container : nil

	end
	if containers.empty?
		puts "No containers found" if containers.empty?
		return nodes_with_euros
	end

	pp containers
	


 # #check if content is different
 # if File.exists?(File.join(ROOT, "tariffs_" + site_arr[1]))
 #   diff = ""
 #   status = Open4::popen4("diff #{File.join(ROOT, "tariffs_" + site_arr[1])} -") do |pid, stdin, stdout, stderr|
 #     stdin.puts new_content
 #     stdin.close
 #     diff = stdout.read
 #   end
 #   #sent mail if content is different
 #   if status != 0
 #     write "change detected."
 #     notify_changed_site(site_arr, diff)
 #   end
 # end
 # 
 # #overwrite the old content with the new one
 # File.open(File.join(ROOT, "tariffs_" + site_arr[1]), "w") do |f|
 #   f.puts new_content
 # end
end

def redirect?(http, uri)
  resp = http.get(uri.path)
  return true if resp.code != "200"
  return false
end

def check_sites
  write "checking hi..."
  begin
    check_site(HI_MET_TOESTEL) { |doc| (doc/"table.collapsable") }
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(HI_SIM_ONLY) { |doc| (doc/"table.collapsable") }
  rescue Exception => e
    handle_exception(e)
  end
  write "checking t-mobile..."
  begin
    check_site(T_MOBILE_RELAX_SIM_ONLY) { |doc| (doc/'*[@id="ctl00_ctl00_ctl04_rowRepeater_ctl01_columnRepeater_ctl00_cellRepeater_ctl00_ctl00_ctl14"]') }
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(T_MOBILE_RELAX) { |doc| (doc/'*[@id="ctl00_ctl00_ctl04_rowRepeater_ctl01_columnRepeater_ctl00_cellRepeater_ctl00_ctl00_ctl06"]') }
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(T_MOBILE_VOORDEELSIM) { |doc| (doc/'*[@id="ctl00_ctl00_ctl04_rowRepeater_ctl01_columnRepeater_ctl00_cellRepeater_ctl00_ctl00_ctl18"]') }
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(T_MOBILE_IPHONE) { |doc| (doc/'*[@id="ctl00_ctl00_ctl04_rowRepeater_ctl01_columnRepeater_ctl00_cellRepeater_ctl00_ctl00_ctl10"]') }
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(T_MOBILE_RELAX_ONLINE) { |doc| (doc/'*[@id="ctl00_ctl00_ctl04_rowRepeater_ctl01_columnRepeater_ctl00_cellRepeater_ctl00_ctl00_ctl02"]') }
  rescue Exception => e
    handle_exception(e)
  end
  write "checking vodafone..."
  begin
    check_site(VODAFONE_BELLEN) { |doc| (doc/"/html/body/div[2]/div[2]/div[7]/div/div/table") }
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(VODAFONE_BELLEN_SMS) { |doc| (doc/"/html/body/div[2]/div[2]/div[10]/div/div/table") }
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(VODAFONE_BELLEN_SMS_WEB) { |doc| (doc/"/html/body/div[2]/div[2]/div[7]/div/div/table") }
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(VODAFONE_BELLEN_SMS_SO) { |doc| (doc/"/html/body/div[2]/div[2]/div[9]/div/div/table") }
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(VODAFONE_BELLEN_SMS_WEB_SO) { |doc| (doc/"/html/body/div[2]/div[2]/div[9]/div/div/table") }
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(VODAFONE_SCHERP) { |doc| (doc/"/html/body/div[2]/div[2]/div[11]/div/table") }
  rescue Exception => e
    handle_exception(e)
  end
  write "checking telfort..."
  begin
    check_site (TELFORT_MET_TOESTEL) {|doc| (doc/'*[@class="step"]')}
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(TELFORT_UNLIMITED) {|doc| (doc/'*[@class="step"]')}
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(TELFORT_SIM_ONLY) {|doc| (doc/'*[@class="step"]')}
  rescue Exception => e
    handle_exception(e)
  end
  write "checking kpn..."
  begin
    check_site(KPN) {|doc| (doc/'//table[@class="kpn-table"]')}
  rescue Exception => e
    handle_exception(e)
  end
  begin
    check_site(KPN_SIM_ONLY) {|doc| (doc/'//div[@id="tabcontent3"]//table')}
  rescue Exception => e
    handle_exception(e)
  end
  write "checking ben..."
  begin
    check_site(BEN) {|doc| (doc/'//*[@id="mainContent"]/div')}
  rescue Exception => e
    handle_exception(e)
  end
  
  write "checking gsmarena..."
  begin
    check_site(GSMARENA) {|doc| (doc/'//*[@id="latest-phones"]')}
  rescue Exception => e
    handle_exception(e)
  end
  write "checking esato..."
  begin
    check_site(ESATO) {|doc| (doc/'//*[@id="phoneindexwrapper"]')}
  rescue Exception => e
    handle_exception(e)
  end
  
  write "checking inlog tmobile..."
  begin
    check_site(INLOG_TMOBILE) {|doc| (doc/ '//*[contains(@class,"login")]')}
  rescue Exception => e
    handle_exception(e)
  end
  write "checking inlog kpn..."
  begin
    check_site(INLOG_KPN) {|doc| (doc/ "//div[@id=\"ph_content\"]//div[@class=\"javaScriptContainer\"]")}
  rescue Exception => e
    handle_exception(e)
  end
  write "checking inlog hi..."
  begin
    check_site(INLOG_HI) {|doc| (doc/ '//*[@id="myhi-login"]')}
  rescue Exception => e
    handle_exception(e)
  end
  write "checking inlog vodafone..."
  begin
    #they do some weird cookie setting redirect dance.
    # check_site(INLOG_VODAFONE) {|doc| (doc/ '/html/body/div[2]/div[2]/div[2]/div/div[2]/div/form/fieldset')}
  rescue Exception => e
    handle_exception(e)
  end
  write "checking inlog telfort..."
  begin
    check_site(INLOG_TELFORT) {|doc| (doc/ '//*[@class="section-login"]')}
  rescue Exception => e
    handle_exception(e)
  end
  
  write "done"
end

# check_site(KPN_SIM_ONLY) {|doc| (doc/'//div[@id="tabcontent3"]//table')}
#check_sites
check_site(KPN)
