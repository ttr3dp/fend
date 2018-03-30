require "spec_helper"

require "ostruct"
require "date"
require "bigdecimal"

RSpec.describe "value helpers plugin" do
  let(:validation) { Class.new(Fend) { plugin :value_helpers } }
  let(:param_class) { validation::Param }

  describe "#dig" do
    let(:value) { nil }
    let(:param) { param_class.new(value) }

    context "when value is a hash" do
      let(:value) { { address: { street: "Elm street", city: { name: "Mordor", zip: 666 } } } }

      it "fetches nested values" do
        param
        expect(param.dig(:address)).to eq(street: "Elm street", city: { name: "Mordor", zip: 666 })
        expect(param.dig(:address, :street)).to eq("Elm street")
        expect(param.dig(:address, :city)).to eq(name: "Mordor", zip: 666)
        expect(param.dig(:address, :city, :name)).to eq("Mordor")
        expect(param.dig(:address, :city, :zip)).to eq(666)
      end
    end

    context "when value is an array" do
      let(:value) { [:root_0, [:nested_1_0, :nested_1_1, [:nested_2_0, :nested_2_1]], :root_2] }

      it "fetches nested values" do
        expect(param.dig(0)).to eq(:root_0)
        expect(param.dig(1)).to eq([:nested_1_0, :nested_1_1, [:nested_2_0, :nested_2_1]])
        expect(param.dig(1, 0)).to eq(:nested_1_0)
        expect(param.dig(1, 1)).to eq(:nested_1_1)
        expect(param.dig(1, 2)).to eq([:nested_2_0, :nested_2_1])
        expect(param.dig(1, 2, 0)).to eq(:nested_2_0)
        expect(param.dig(1, 2, 1)).to eq(:nested_2_1)
        expect(param.dig(2)).to eq(:root_2)
      end
    end

    context "when value is a combination of hashes and arrays" do
      let(:value) {
        {
          username: "foo",
          address: {
            street: "Elm street",
            details: { location: [1111, 2222] }
          },
          tags: [
            { id: 1, name: "tag 1" }
          ]
        }
      }

      it "feches nested values" do
        expect(param.dig(:username)).to eq("foo")

        expect(param.dig(:address)).to eq(street: "Elm street", details: { location: [1111, 2222] })
        expect(param.dig(:address, :street)).to eq("Elm street")
        expect(param.dig(:address, :details)).to eq(location: [1111, 2222])
        expect(param.dig(:address, :details, :location)).to eq([1111, 2222])
        expect(param.dig(:address, :details, :location, 0)).to eq(1111)
        expect(param.dig(:address, :details, :location, 1)).to eq(2222)

        expect(param.dig(:tags)).to eq([{ id: 1, name: "tag 1" }])
        expect(param.dig(:tags, 0)).to eq({ id: 1, name: "tag 1" })
        expect(param.dig(:tags, 0, :id)).to eq(1)
        expect(param.dig(:tags, 0, :name)).to eq("tag 1")
      end
    end

    context "when path is invalid" do
      let(:value) { {} }

      it "returns nil" do
        expect(param.dig(:adress)).to be_nil
        expect(param.dig(:adress, :city)).to be_nil

        expect(param.dig(0, 1, 2)).to be_nil
      end
    end
  end

  describe "#present?" do
    it "returns true when value is present" do
      [1, "test", " test     ", :test, Object.new, OpenStruct.new(empty?: false), [1, 2, 3], { one: 1 }, true].each do |present_value|
        expect(param_class.new(present_value)).to be_present
      end
    end

    it "returns false when value is blank" do
      [nil, "", "    ", "\r", "\n", "\t", " \n\r\t  ", [], {}, false, OpenStruct.new(empty?: true)].each do |blank_value|
        expect(param_class.new(blank_value)).not_to be_present
      end
    end
  end

  describe "#blank?" do
    it "returns false when value is present" do
      [1, "test", " test     ", :test, Object.new, OpenStruct.new(empty?: false), [1, 2, 3], { one: 1 }, true].each do |present_value|
        expect(param_class.new(present_value)).not_to be_blank
      end
    end

    it "returns true when value is blank" do
      [nil, "", "    ", "\r", "\n", "\t", " \n\r\t  ", [], {}, false, OpenStruct.new(empty?: true)].each do |blank_value|
        expect(param_class.new(blank_value)).to be_blank
      end
    end
  end

  describe "#empty_string?" do
    it "returns true when value is an empty string" do
      ["", "    ", "\r", "\n", "\t", " \n\r\t  "].each do |empty_string|
        expect(param_class.new(empty_string)).to be_empty_string
      end
    end

    it "returns false when value is not an empty string" do
      ["a", "    a", "foo \r", "bar \n", "\t          baz", "foo   bar \n\r\t baz "].each do |non_empty_string|
        expect(param_class.new(non_empty_string)).not_to be_empty_string
      end
    end
  end

  describe "#type_of?" do
    context "when argument is a class" do
      it "checks by invoking #is_a? on value" do
        param = param_class.new("foo")

        allow(param.value).to receive(:is_a?).and_return("is_a? INVOKED")
        FakeClass = Class.new

        [String, Integer, Float, TrueClass, FalseClass, Date, Time, DateTime, FakeClass].each do |klass|
          expect(param.type_of?(klass)).to eq("is_a? INVOKED")
        end
      end
    end

    context "when argument is a string or a symbol" do
      context "when argument value is 'boolean'" do
        it "returns true if value is TrueClass or FalseClass and false otherwise" do
          true_param = param_class.new(true)
          false_param = param_class.new(false)

          non_bool_param = param_class.new("boolean")

          ["boolean", :boolean].each do |ref|
            expect(true_param).to be_type_of(ref)
            expect(false_param).to be_type_of(ref)

            expect(non_bool_param).not_to be_type_of(ref)
          end

        end
      end

      context "when argument value is 'decimal'" do
        it "returns true if value is Float or BigDecimal and false otherwise" do
          float_param = param_class.new(25.045)
          big_decimal_param = param_class.new(BigDecimal.new(25))

          non_decimal_param = param_class.new("decimal")

          ["decimal", :decimal].each do |ref|
            expect(float_param).to be_type_of(ref)
            expect(big_decimal_param).to be_type_of(ref)

            expect(non_decimal_param).not_to be_type_of(ref)
          end
        end
      end

      context "when argument value is 'nil'" do
        it "returns true if value is NilClass and false otherwise" do
          nil_param = param_class.new(nil)

          non_nil_param = param_class.new("nil")

          ["nil", :nil].each do |ref|
            expect(nil_param).to be_type_of(ref)

            expect(non_nil_param).not_to be_type_of(ref)
          end
        end
      end

      it "returns true when constantized argument matches value class" do
        { string: "string", integer: 1, float: 4.4, big_decimal: BigDecimal.new(1), date: Date.new, time: Time.new,
          date_time: DateTime.new, array: Array.new, hash: Hash.new, true_class: true, false_class: false, symbol: :sym }.each do |arg, value|
          param = param_class.new(value)

          [arg, arg.to_s].each { |ref| expect(param).to be_type_of(ref) }
        end
      end

      it "returns false when constantized argument does not matche value class" do
        { string: 1, integer: "1", float: nil, big_decimal: :foo, date: "date", time: "time",
          date_time: "datetime", array: Hash.new, hash: Array.new, true_class: 1, false_class: 0, symbol: "sym" }.each do |arg, value|
          param = param_class.new(value)

          [arg, arg.to_s].each { |ref| expect(param).not_to be_type_of(ref) }
        end
      end

      it "raises error if constant is uninitialized" do
        [:foo, "foo"].each do |uninit_const|
          expect { param_class.new(uninit_const).type_of?(uninit_const) }.to raise_error(NameError, "uninitialized constant Foo")
        end
      end
    end
  end
end
