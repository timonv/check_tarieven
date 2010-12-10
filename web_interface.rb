require 'sinatra'
require './check_tarieven.rb'

agg = Aggregator.new
get '/kpn' do
	agg.check_site(KPN).to_s
end

get '/tmobilerelax' do
	agg.check_site(T_MOBILE_RELAX).to_s
end
