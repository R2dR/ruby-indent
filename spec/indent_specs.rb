require_relative './spec_helper'
include RBeautify

describe RBoo do

	describe "indenting HERE DOC without terminator" do
		rboo = RBoo.text("<<-RUBY")
		rboo.indent
		it "indicates inside_here_doc" do
			rboo.inside_here_doc?.should be_true
		end		
	end
	describe "indenting HERE DOC with indented terminator" do
		code = %q{
			<<-RUBY
			RUBY
		}
		rboo = RBoo.text(code)
		rboo.indent
		it "indicates not inside_here_doc" do
			rboo.inside_here_doc?.should be_false
		end
	end
	
	describe "indenting unterminated block comment" do
		rboo = RBoo.text("=begin")
		rboo.indent
		it "indicates inside comment" do
			rboo.inside_block_comment?.should be_true
		end
	end

	describe "indenting terminated block comment" do
		rboo = RBoo.text %q{
				=begin
				=end
			}.left_adjust(0)
		rboo.indent
		it "indicates not inside comment" do
			rboo.inside_block_comment?.should_not be_true
		end
	end
	
	describe "indenting with __END__ inside block comments" do
		rboo = RBoo.text %q{
				=begin
				__END__
				=end
			}.left_adjust(0)
		rboo.indent
		it "does not indicate end of source" do
			rboo.after_source_end?.should_not be_true
		end
	end
	
	describe "indenting with __END__ inside HERE DOC" do
		rboo = RBoo.text %q{
			<<-RUBY
			__END__
			RUBY
		}.left_adjust(0)
		
		it "does not indicate end of source" do
			rboo.after_source_end?.should_not be_true
		end		
	end
end

describe "Indent" do

	describe "do %Q{" do
		result = %q{
			somemethod do %Q{
			inner_content
			}
			end
		}.indent
		
		it "double indents inner_content" do
			result.should double_indent(:inner_content)
		end
	end

	describe "if-condition statement" do
		result = %q{
			if something? 
			true_condition
			else
			false_condition
			end
		}.indent
		
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
	
	describe "multi-line method call" do
		result = %q{
			def method(param1,
			param2,
			param3)
			line_after
		}.indent
		
		it "doesn't indent the method def" do
			result.should_not indent('def method')
		end
		it "indents the parameter of 2nd line" do
			result.should single_indent(:param2)
		end
		it "indents the parameter of 3rd line" do
			result.should single_indent(:param3)
		end
		it "doesn't indent the line after" do
			result.should_not indent(:line_after)
		end		
	end	
	
#	describe "double indention on same line" do
	
#	end

end



