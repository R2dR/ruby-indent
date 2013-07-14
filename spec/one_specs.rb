require_relative './spec_helper'


describe RBoo do
	rboo = RBoo.text("")
	it "recognizes Here Doc starts and term" do
		["<<HERE", "<<-HERE", "<<'HERE'", "<<-'HERE'", '<<"HERE"',
			'<<-"HERE"'
		].each do |phrase|
			rboo.is_here_doc_start?(phrase).should be_true
			rboo.scan_here_doc_term(phrase).should == 'HERE'
		end
	end	
	it "recognizes more complex HERE DOC starts and terms" do
		[
			"do <<HERE", "out =<<HERE"
		].each do |phrase|
			rboo.is_here_doc_start?(phrase).should be_true
			rboo.scan_here_doc_term(phrase).should == 'HERE'
		end		
	end
	it "does not accept invalid HERE DOC starts" do
		[
			"array<<HERE", "ar << 'HERE'"
		].each do |phrase|
			rboo.is_here_doc_start?(phrase).should be_false
		end
	end
	
end

