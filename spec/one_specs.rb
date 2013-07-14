require_relative './spec_helper'


describe RBoo do

	describe "if-statement" do
		indent %q{
			if something? 
			true_condition
			else
			false_condition
			end
		}
		
		it "doesn't indent if, else and end" do
			[:if, :else, :end].each do |line|
				result.should_not indent(line)
			end
		end
		it "single indents the true_condition" do
			result.should single_indent(:true_condition)
		end
		it "single indents the false_condition" do
			result.should single_indent(:false_condition)
		end
	end

end

