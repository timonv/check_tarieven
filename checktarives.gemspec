Gem::Specification.new do |s|
	s.name				= "checktarives"
	s.summary			= "A simple script to pattermatch check given sites"
	s.description = File.read(File.join(File.dirname(__FILE__), 'README'))
	s.requirements = [ 'mechanize', 'nokogiri', 'net/smtp', 'net/http', 'popen4', 'pp', 'logger','csv', 'rspec' ]
	s.version			= "0.0.1"
	s.authors			= ["Timon Vonk", "Harm Aarts" ]
	s.email				= ["mail@timonv.nl" ]
	s.homepage		= "http://www.delaagsterekening.nl"
	s.platform		= Gem::Platform::RUBY
	s.required_ruby_version = '>=1.9'
	s.files				= Dir['**/**']
	s.executables = [ 'checktarives','convert_data' ]
	s.test_files = Dir["spec/*_spec.rb"]
	s.has_rdoc = true
end
