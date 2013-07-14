require_relative './spec_helper'


describe RBoo do

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
end

