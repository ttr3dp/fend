require "spec_helper"

RSpec.describe Fend::Result do
  let(:result) do
    described_class.new(input: { test: "test" }, output: { test: "TEST" }, errors: { test: ["must be integer"] })
  end

  describe ".fend_class" do
    it "references namespace class" do
      expect(described_class.fend_class).to be(Fend)

      subclass = Class.new(Fend)
      expect(subclass::Result.fend_class).to be(subclass)
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
