require "spec_helper"

RSpec.describe Fend::Param do
  let(:param) { described_class.new(foo: :bar) }

  describe ".fend_class" do
    it "references namespace class" do
      expect(described_class.fend_class).to be(Fend)

      subclass = Class.new(Fend)
      expect(subclass::Param.fend_class).to be(subclass)
    end
  end

  describe "#initialize" do
    it "sets properties" do
      expect(param.value).to eq(foo: :bar)
      expect(param.errors).to eq([])
    end
  end

  describe "#[]" do
    context "when current value is hash" do
      it "returns nested hash value" do
        expect(param[:foo]).to eq(:bar)
      end
    end

    context "when current value is array" do
      it "returns member by index" do
        param = described_class.new([1, 2, 3])
        expect(param[0]).to eq(1)
        expect(param[1]).to eq(2)
        expect(param[2]).to eq(3)
      end
    end

    context "when current value is not hash nor array" do
      it "returns nil" do
        param = described_class.new("foo")

        expect(param[:foo]).to be_nil
      end
    end
  end

  describe "#param" do
    it "validates nested param" do
      param.param(:test) { |test| test.add_error("invalid") }

      expect(param.errors).to eq(test: ["invalid"])
    end
  end

  describe "#each" do
    let(:param) { described_class.new(foo: [1, 2, 3]) }

    it "validates array params" do
      param.param(:foo) do |foo|
        foo.each do |f|
          f.add_error("must be string") unless f.value.is_a?(String)
        end
      end

      expect(param.errors).to eq(foo: { 0 => ["must be string"], 1 => ["must be string"], 2 => ["must be string"] })
    end

    context "with index" do
      it "provides index as block argument" do
        param.param(:foo) do |foo|
          foo.each do |f, index|
            f.add_error("invalid") unless index.eql?(1)
          end
        end

        expect(param.errors).to eq(foo: { 0 => ["invalid"],  2 => ["invalid"] })
      end
    end
  end

  describe "#valid" do
    it "returns true if no errors, false otherwise" do
      expect(param).to be_valid

      param.errors << ["invalid"]
      expect(param).not_to be_valid
    end
  end

  describe "#invalid" do
    it "returns true if errors are present, false otherwise" do
      expect(param).not_to be_invalid

      param.errors << ["invalid"]
      expect(param).to be_invalid
    end
  end

  describe "#add_error" do
    it "appends error message" do
      param.add_error "new error"
      expect(param.errors).to eq(["new error"])
    end
  end
end
