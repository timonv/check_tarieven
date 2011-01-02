require 'spec_helper'

module CheckTarives
	describe Aggregator do
		describe "#check_site" do
			before(:each) do
				data = CheckTarives::Data.get_pretty
				@agg = CheckTarives::Aggregator.new(data[0][:url],data[0][:name])
			end
		end
	end
end
