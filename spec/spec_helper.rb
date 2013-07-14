require 'rspec'
require_relative '../rboo'
include RBeautify

RSpec::Core::ExampleGroup.class_eval do
  class << self
    def indent(text="")
      rboo = RBoo.text(text)
      rboo.indent
      let(:rboo) do
        rboo
      end
      let(:result) do
        rboo.output
      end
    end
  end
end

module IndentationMethods
  def test_indentation?(result, selector, length)
    @expected_length = length
    if selector.is_a?(Fixnum)
      @lines = (line = result.split(/\n/)[selector-1]) ? [line] : []
    else
        @lines = result.split(/\n/).grep(/#{selector}/)
     end
      case @lines.size
      when 1
        (@actual_length = (@test_line = @lines.first).indention_spaces) == @expected_length
      when 0
        raise "Invalid selector: #{selector} does not match any lines in '#{result}'"
      else
         raise "Ambiguous selector: #{match} matches more than one line"
    end
  end
  def default_failure_message
    "expected \"#{@test_line}\" to have #{@expected_length} space indentation (has #{@actual_length})"
  end
  def default_not_failure_message
    "expected \"#{@test_line}\" to not have #{@expected_length} space indentation (has #{@actual_length})"
  end
end

RSpec::Matchers.define :mismatch do
  match do |rboo|
    rboo.tab_count != 0
  end
  failure_message_for_should do |actual|
    "tab_count == #{actual.tab_count}"
  end
  failure_message_for_should_not do |actual|
    "tab_count == #{actual.tab_count}"
  end
end
RSpec::Matchers.define :indent do |line_selector|
  include IndentationMethods
   match do |result|
     !test_indentation?(result, line_selector, 0)
  end
  failure_message_for_should do |actual|
    default_failure_message
  end
  failure_message_for_should_not do |actual|
    default_not_failure_message
  end
end
RSpec::Matchers.define :single_indent do |line_selector|
  include IndentationMethods
   match do |result|
     test_indentation?(result, line_selector, 2)
  end
  failure_message_for_should do |actual|
    default_failure_message
  end
  failure_message_for_should_not do |actual|
    default_not_failure_message
  end
end
RSpec::Matchers.define :double_indent do |line_selector|
  include IndentationMethods
   match do |result|
     test_indentation?(result, line_selector, 4)
  end
  failure_message_for_should do |actual|
    default_failure_message
  end
  failure_message_for_should_not do |actual|
    default_not_failure_message
  end
end

String.class_eval do
  def indent
    RBeautify::RBoo.text(self).indent
  end
end

String.class_eval do
  def lines_for(matcher)
    @splitted ||= self.split(/\n/)
    @splitted.grep(/#{matcher}/).first
  end
  def line_for(matcher)
    lines_for(matcher).first
  end
  def indention_spaces
    leader = self.scan(/^\s*/).first
    leader ? leader.size : 0
  end
  def indention_for(text)
    line_for(text).indention_spaces
  end
  def left_adjust(padding='')
    padding = " "*padding if padding.is_a?(Fixnum)
    lines = self.split(/\n/).map{|l| l.gsub(/\t/," "*2) }
    sig_lines = lines.grep(/\S+/)
    remove_spaces = " " * sig_lines.map{|l| l.scan(/^\s*/).first.length }.min
    lines.map{|l| l.sub(/^#{remove_spaces}/, padding) }.join("\n")
  end
end





