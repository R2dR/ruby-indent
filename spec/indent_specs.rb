require_relative './spec_helper'

describe "Indent" do
  describe "method call with multiline hash" do
    indent <<-EXAMPLE
    callmethod({
      opt1: something,
      opt2: another thing
    })
    EXAMPLE
    it "does not mismatch" do
      rboo.should_not mismatch
    end
  end

  describe "single-line methods" do
    indent <<-EXAMPLE
      class MyClass
      def mymethod() something end
      end
    EXAMPLE
    it "does not mismatch" do
      rboo.should_not mismatch
    end
    it "single indents the method" do
      result.should single_indent(:mymethod)
    end
  end

  describe "single-line if-statement" do
    indent "if true; puts 'ok' else puts 'not' end"
    it "does not indent line" do
      result.should_not indent(1)
    end
    it "ends without mismatch" do
      rboo.should_not mismatch
    end
  end

  describe "single-line if-statement with then" do
    indent "if true then puts 'ok' else puts 'not' end"
    it "does not indent line" do
      result.should_not indent(1)
    end
    it "ends without mismatch" do
      rboo.should_not mismatch
    end
  end

  describe "single-line method" do
    indent "def method() do_something end"
    it "does not indent the method line" do
      result.should_not indent(:def)
    end
    it "ends without mismatch" do
      rboo.should_not mismatch
    end
  end

  describe "eigenclass (class << something)" do
    indent "class << Something"
    it "indents once" do
      rboo.tab_count.should == 1
    end
    it "is not in a HERE DOC" do
      rboo.inside_here_doc?.should be_false
    end
  end

  describe "do <<-HEREDOC block" do
    indent <<-EXAMPLE
      somemethod do <<-HEREDOC
      inside_here_doc
      HEREDOC
      outside_here_doc
      end
      outside_do_block
    EXAMPLE
    it "finishes without mismatch" do
      rboo.should_not mismatch
    end
    it "single indents closing HEREDOC term" do
      result.should single_indent(3)
    end
  end

  describe "unclosed do <<-HEREDOC" do
    indent "something do <<-HEREDOC"
    it "indicates 2 tab count" do
      rboo.tab_count.should == 2
    end
    it "indicates inside here doc" do
      rboo.inside_here_doc?.should be_true
    end
  end

  describe "do %Q{" do
    indent <<-EXAMPLE
      somemethod do %Q{
      inner_content
      }
      end
      outside_do_block
    EXAMPLE

    it "finishes without mismatch" do
      rboo.should_not mismatch
    end
  end

  describe "nested if-statement" do
    indent <<-EXAMPLE
      if something?
      single_true_condition
      if other?
      double_true_condition
      end
      end
    EXAMPLE

    it "double indents the double_true_condition" do
      result.should double_indent(:double_true_condition)
      rboo.should_not mismatch
    end
    it "single indents the 'if other?' line" do
      result.should single_indent('if other?')
    end
  end

  describe "if-statement" do
    indent <<-EXAMPLE
      if something?
      true_condition
      else
      false_condition
      end
    EXAMPLE

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
    indent <<-EXAMPLE
      def method(param1,
      param2,
      param3)
      method_content
      end
      line_after
    EXAMPLE

    it "doesn't indent the method def" do
      result.should_not indent('def method')
    end
    it "double indents the parameter of 2nd line" do
      result.should double_indent(:param2)
    end
    it "double indents the parameter of 3rd line" do
      result.should double_indent(:param3)
    end
    it "single indents the method content" do
      result.should single_indent(:method_content)
    end
    it "doesn't indent the line after" do
      result.should_not indent(:line_after)
    end
  end

  describe "here doc with assignment" do
    indent %q{
      out = <<-HEREDOC
      inside
      HEREDOC
      outside
    }.left_adjust(0)

    it "does not indent line with assignment" do
      result.should_not indent('out =')
    end
    it "does not indent inside content" do
      result.should_not indent(:inside)
    end
    it "does not indent outside" do
      result.should_not indent(:outside)
    end
  end
end

describe RBoo do
  indent ""
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
      "=<<HERE", " = <<'HERE'"
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

describe RBoo do
  describe "indenting HERE DOC without terminator" do
    indent "<<-HEREDOC"
    it "indicates inside_here_doc" do
      rboo.inside_here_doc?.should be_true
    end
  end

  describe "indenting HERE DOC with assignment and without terminator" do
    indent "out = <<-HEREDOC"
    it "indicates inside_here_doc" do
      rboo.inside_here_doc?.should be_true
    end
  end

  describe "indenting HERE DOC with indented terminator" do
    indent %q{
      <<-HEREDOC
      HEREDOC
    }
    it "indicates not inside_here_doc" do
      rboo.inside_here_doc?.should be_false
    end
  end

  describe "indenting unterminated block comment" do
    indent "=begin"
    it "indicates inside comment" do
      rboo.inside_comment_block?.should be_true
    end
  end

  describe "indenting terminated block comment" do
    indent %q{
        =begin
        =end
    }.left_adjust(0)
    it "indicates not inside comment" do
      rboo.inside_comment_block?.should_not be_true
    end
  end

  describe "indenting with __END__ inside block comments" do
    indent %q{
        =begin
        __END__
        =end
    }.left_adjust(0)
    it "does not indicate end of source" do
      rboo.inside_source_code?.should be_true
    end
  end

  describe "indenting with __END__ inside HERE DOC" do
    indent %q{
      <<-HEREDOC
      __END__
      HEREDOC
    }.left_adjust(0)
    it "does not indicate end of source" do
      rboo.inside_source_code?.should be_true
    end
  end

  describe "indenting here doc with end inside" do
    indent %q{
      out = <<-HEREDOC
      something
      end
      HEREDOC
    }
    it "does not indicate mismatch error" do
      rboo.should_not mismatch
    end
  end

end

