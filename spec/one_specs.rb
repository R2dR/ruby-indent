require_relative './spec_helper'

describe "Indent" do

	describe "indenting with __END__ inside HERE DOC" do
		rboo = RBoo.text %q{
			<<-RUBY
			__END__
			RUBY
		}.left_adjust(0)
		rboo.indent
		
		it "does not indicate end of source" do
			rboo.source_code_ended?.should_not be_true
		end		
	end
	
end
