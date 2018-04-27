require "spec_helper"
require "fend"

RSpec.describe "Fend" do
  let(:validation_class) { Class.new(Fend) }
  let(:validation) { validation_class.new }

  describe ".inherited" do
    it "duplicates options to subclass" do
      validation_class.opts[:test] = "test"

      subclass = Class.new(validation_class)

      expect(subclass.opts[:test]).to eq "test"

      subclass.opts[:test] = :test

      expect(validation_class.opts[:test]).to eq "test"
      expect(subclass.opts[:test]).to eq :test
    end

    it "duplicates enumerable option values" do
      validation_class.opts[:arr]    = [1, 2]
      validation_class.opts[:hash]   = { one: 1, two: 2 }
      validation_class.opts[:frozen] = { one: 1 }.freeze

      subclass = Class.new(validation_class)

      subclass.opts[:arr] << 3

      expect(subclass.opts[:arr]).to eq [1, 2, 3]
      expect(validation_class.opts[:arr]).to eq [1, 2]

      subclass.opts[:hash].merge!(two: "two")
      expect(subclass.opts[:hash]).to eq(one: 1, two: "two")

      expect(validation_class.opts[:hash]).to eq(one: 1, two: 2)

      expect(subclass.opts[:frozen]).to eq(one: 1)
    end

    it "duplicates core classes" do
      expect(Fend::Param).not_to be validation_class::Param
      expect(validation_class).to be validation_class::Param::fend_class

      expect(Fend::Result).not_to be validation_class::Result
      expect(validation_class).to be validation_class::Result::fend_class
    end
  end

  describe ".validation_block" do
    it "keeps validation specs" do
      block = -> { "foo" }

      validation_class.validate(&block)

      expect(validation_class.validation_block).to be block
    end
  end

  describe ".call" do
    it "invokes #call" do
      allow_any_instance_of(validation_class).to receive(:call).and_return("call invoked")

      expect(validation_class.call("foo")).to eq("call invoked")
    end
  end

  describe "#validation_block" do
    it "returns .validation_block" do
      validation_class.validate { "foo" }

      expect(validation_class.validation_block).to eq validation.validation_block
    end
  end

  describe "#param_class" do
    it "returns param class" do
      expect(validation.param_class).to eq(validation_class::Param)
    end
  end

  describe "#input_class" do
    it "returns input class" do
      expect(validation.result_class).to eq(validation_class::Result)
    end
  end

  describe "#result" do
    it "returns result object" do
      result = validation.result(input: :foo, output: :bar, errors: :baz)

      expect(result.input).to eq(:foo)
      expect(result.output).to eq(:bar)
      expect(result.messages).to eq(:baz)
    end
  end

  describe "#call" do
    before do
      validation_class.validate  do |i|
        i.params(:username) do |username|
          username.add_error("must be present") if username.value.nil? || username.value == ''
        end

        i.params(:age) do |age|
          age.add_error("must be integer") unless age.value.is_a?(Integer)
        end

        i.params(:address) do |address|
          address.add_error("must be hash") unless address.value.is_a?(Hash)
        end

        i.params(:interests) do |interests|
          interests.add_error("must be array") unless interests.value.is_a?(Array)
        end
      end
    end

    it "returns validation result" do
      input = { address: nil, interests: 2 }

      expected_messages = {
        username:  ["must be present"],
        age:       ["must be integer"],
        address:   ["must be hash"],
        interests: ["must be array"],
      }

      result = validation.call(input)

      expect(result).to be_an_instance_of(validation_class::Result)
      expect(result.input).to eq(input)
      expect(result.output).to eq(input)
      expect(result).to be_failure
      expect(result).not_to be_success
      expect(result.messages).to eq(expected_messages)
    end

    context "when input is valid" do
      it "returns no messages within result" do
        input = { username: "foo", age: 66, address: {}, interests: [] }

        result = validation.call(input)

        expect(result).to be_success
        expect(result).not_to be_failure
        expect(result.messages).to be_empty
      end
    end

    context "when params are nested" do
      before do
        validation_class.validate do |i|
          i.params(:address) do |address|
            address.add_error("must be hash") unless address.value.is_a?(Hash)

            address.params(:city) do |city|
              city.add_error("must be present") if city.value.nil? || city.value == ''
              city.add_error("must be string") unless city.value.is_a?(String)
            end

            address.params(:street) do |street|
              street.add_error("must be present") if street.value.nil? || street.value == ''
              street.add_error("must be string") unless street.value.is_a?(String)
            end

            address.params(:zip) do |zip|
              zip.add_error("must be present") if zip.value.nil?
              zip.add_error("must be integer") unless zip.value.is_a?(Integer)
            end
          end

          i.params(:interests) do |interests|
            interests.add_error("must be array") unless interests.value.is_a?(Array)

            interests.each do |interest|
              interest.add_error("must be string") unless interest.value.is_a?(String)
            end
          end
        end
      end

      it "nests messages under parent param" do
        input = { address: {}, interests: [1, 2, 3, "string"] }

        expected = {
          address: {
            city: ["must be present", "must be string"],
            street: ["must be present", "must be string"],
            zip: ["must be present", "must be integer"]
          },
          interests: {
            0 => ["must be string"],
            1 => ["must be string"],
            2 => ["must be string"]
          }
        }

        expect(validation.call(input).messages).to eq(expected)
      end

      context "when parent param is invalid" do
        it "skips nested params validation" do
          expected = { address: ["must be hash"], interests: ["must be array"] }

          expect(validation.call({}).messages).to eq(expected)
        end
      end
    end
  end
end
