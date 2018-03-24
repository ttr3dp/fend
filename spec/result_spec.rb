require "spec_helper"

RSpec.describe Egis::Result do
  let(:result) do
    described_class.new(input: { test: "test" }, output: { test: "TEST" }, errors: { test: ["must be integer"] })
  end

  describe ".egis_class" do
    it "references namespace class" do
      expect(described_class.egis_class).to be(Egis)

      subclass = Class.new(Egis)
      expect(subclass::Result.egis_class).to be(subclass)
    end
  end

  describe "#initialize" do
    it "sets properties" do
      expect(result.input).to eq(test: "test")
      expect(result.output).to eq(test: "TEST")
    end
  end

  describe "#messages" do
    it "returns error messages" do
      expect(result.messages).to eq(test: ["must be integer"])
    end
  end

  describe "#failure?" do
    it "returns true if messages exist and false otherwise" do
      expect(result).to be_failure

      result = described_class.new(input: nil, output: nil, errors: {})
      expect(result).not_to be_failure
    end
  end

  describe "#success?" do
    it "returns false if messages exist and true otherwise" do
      expect(result).not_to be_success

      result = described_class.new(input: nil, output: nil, errors: {})
      expect(result).to be_success
    end
  end
end
