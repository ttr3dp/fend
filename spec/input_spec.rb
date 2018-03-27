require "spec_helper"

RSpec.describe Fend::Input do
  let(:input) { described_class.new(foo: :bar) }

  describe ".fend_class" do
    it "references namespace class" do
      expect(described_class.fend_class).to be(Fend)

      subclass = Class.new(Fend)
      expect(subclass::Input.fend_class).to be(subclass)
    end
  end

  describe "#initialize" do
    it "sets properties" do
      expect(input.value).to eq(foo: :bar)
      expect(input.errors).to eq([])
    end
  end

  describe "#param" do
    it "validates nested param" do
      input.param(:test) { |test| test.add_error("invalid") }

      expect(input.errors).to eq(test: ["invalid"])
    end
  end

  describe "#params" do
    it "validates nested params" do
      input.params(:foo, :bar, :baz) do |foo, bar, baz|
        foo.add_error("invalid foo") unless foo.value.eql?(:bar)
        bar.add_error("invalid bar")
        baz.add_error("invalid baz")
      end

      expect(input.errors).to eq(bar: ["invalid bar"], baz: ["invalid baz"])
    end
  end

  describe "#each" do
    let(:input) { described_class.new(foo: [1, 2, 3]) }

    it "validates array params" do
      input.param(:foo) do |foo|
        foo.each do |f|
          f.add_error("must be string") unless f.value.is_a?(String)
        end
      end

      expect(input.errors).to eq(foo: { 0 => ["must be string"], 1 => ["must be string"], 2 => ["must be string"] })
    end

    context "with index" do
      it "provides index as block argument" do
        input.param(:foo) do |foo|
          foo.each do |f, index|
            f.add_error("invalid") unless index.eql?(1)
          end
        end

        expect(input.errors).to eq(foo: { 0 => ["invalid"],  2 => ["invalid"] })
      end
    end
  end

  describe "#valid" do
    it "returns true if no errors, false otherwise" do
      expect(input).to be_valid

      input.errors << ["invalid"]
      expect(input).not_to be_valid
    end
  end

  describe "#invalid" do
    it "returns true if errors are present, false otherwise" do
      expect(input).not_to be_invalid

      input.errors << ["invalid"]
      expect(input).to be_invalid
    end
  end

  describe "#[]" do
    context "when current value is hash" do
      it "returns nested hash value" do
        expect(input[:foo]).to eq(:bar)
      end
    end

    context "when current value is array" do
      it "returns member by index" do
        input = described_class.new([1, 2, 3])
        expect(input[0]).to eq(1)
        expect(input[1]).to eq(2)
        expect(input[2]).to eq(3)
      end
    end

    context "when current value is not hash nor array" do
      it "returns nil" do
        input = described_class.new("foo")

        expect(input[:foo]).to be_nil
      end
    end
  end

  describe "#add_error" do
    it "appends error message" do
      input.add_error "new error"
      expect(input.errors).to eq(["new error"])
    end
  end
end
