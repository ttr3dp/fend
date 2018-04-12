require "spec_helper"

require "ostruct"
require "date"

RSpec.shared_examples "strict type coercion" do |type, uncoercible_input|
  describe "strict_#{type} coercion" do
    before { setup_validation("strict_#{type}".to_sym, nil) }

    it "raises error" do
      expect { validation.call(test: uncoercible_input) }.to raise_error(Fend::Plugins::Coercions::CoercionError, "cannot coerce #{uncoercible_input.inspect} to #{type}")
    end

    it "raises error with custom message" do
      validation.opts[:coercions_strict_error_message] = "custom message"

      expect { validation.call(test: uncoercible_input) }.to raise_error(Fend::Plugins::Coercions::CoercionError, "custom message")

      validation.opts[:coercions_strict_error_message] = ->(input, coercion_type) { "nope #{input} #{coercion_type}" }

      expect { validation.call(test: uncoercible_input) }.to raise_error(Fend::Plugins::Coercions::CoercionError, "nope #{uncoercible_input} #{type}")
    end
  end
end

RSpec.describe "coercions plugin" do
  let(:validation) { Class.new(Fend) { plugin :coercions } }

  def setup_validation(type, comparison_value)
    validation.coerce(test: type)

    validation.validate do |i|
      i.param(:test) { |t| t.add_error("failed coercion") unless t.value == comparison_value }
    end
  end

  def expect_validation_success(input)
    expect(validation.call(input)).to be_success
  end

  describe "Fend.inherited" do
    it "duplicates Coerce class" do
      subclass = Class.new(validation)

      expect(subclass::Coerce).not_to be(validation)
      expect(subclass::Coerce.fend_class).to be(subclass)
    end

    it "does not duplicate Coercer class" do
      subclass = Class.new(validation)

      expect(subclass::Coercer).to be(validation::Coercer)
    end
  end

  describe "Fend#type_schema" do
    it "returns type schema" do
      validation.coerce(foo: :string, bar: :integer)

      expect(validation.new.type_schema).to eq(foo: :string, bar: :integer)
    end

    it "returns empty hash if unspecified" do
      expect(validation.new.type_schema).to eq({})
    end

    it "raises if schema is of invalid type" do
      validation.coerce([:foo, :bar, :baz])
      expect { validation.new.type_schema }.to raise_error(Fend::Error, "type schema must be hash")
    end
  end

  context "when value is empty string" do
    let(:empty_strings) { ["", "   ", "\n", "\t", "\r", "  \n\r\t "] }

    it "coerces to nil" do
      %i(any string symbol integer float decimal date date_time time boolean).each do |type_ref|
        setup_validation(type_ref, nil)

        empty_strings.each { |empty_string| expect_validation_success(test: empty_string) }
      end
    end

    it "coerces to empty hash" do
      setup_validation(:hash, {})
      empty_strings.each { |empty_string| expect_validation_success(test: empty_string) }
    end

    it "coerces to empty array" do
      setup_validation(:array, [])
      empty_strings.each { |empty_string| expect_validation_success(test: empty_string) }
    end
  end

  describe ":any" do
    it "skips coercion" do
      setup_validation(:any, foo: :bar)
      expect_validation_success(test: { foo: :bar })
    end
  end

  describe ":string" do
    it_behaves_like "strict type coercion", :string, []

    it "returns nil if value is nil" do
      setup_validation(:string, nil)
      expect_validation_success(test: nil)
    end

    it "coerces value by invoking #to_s if input is Numeric or Symbol" do
      setup_validation(:integer, 1)
      expect_validation_success(test: "1")

      setup_validation(:float, 1.1)
      expect_validation_success(test: "1.1")

      setup_validation(:symbol, :symbol)
      expect_validation_success(test: "symbol")
    end

    it "returns input if String" do
      setup_validation(:string, "string")
      expect_validation_success(test: "string")
    end

    describe "when input is uncoercible" do
      it "skips coercion" do
        setup_validation(:string, [])
        expect_validation_success(test: [])
      end
    end
  end

  describe ":symbol" do
    it_behaves_like "strict type coercion", :symbol, []

    it "returns nil if value is nil" do
      setup_validation(:symbol, nil)
      expect_validation_success(test: nil)
    end

    it "coerces value by invoking #to_sym" do
      setup_validation(:symbol, :name)
      expect_validation_success(test: "name")

      setup_validation(:symbol, :symbol)
      expect_validation_success(test: OpenStruct.new(to_sym: :symbol))
    end

    describe "when input is uncoercible" do
      it "skips coercion" do
        setup_validation(:symbol, [])
        expect_validation_success(test: [])
      end
    end
  end

  describe ":integer" do
    it_behaves_like "strict type coercion", :integer, []

    it "coerces value with Kernel.Integer " do
      allow(Kernel).to receive(:Integer).and_return("INTEGER_INVOKED")
      setup_validation(:integer, "INTEGER_INVOKED")
      expect_validation_success(test: "1")
    end

    describe "when input is uncoercible" do
      it "skips coercion" do
        setup_validation(:integer, [])
        expect_validation_success(test: [])
      end
    end
  end

  describe ":float" do
    it_behaves_like "strict type coercion", :float, []

    it "coerces value with Kernel.Float " do
      allow(Kernel).to receive(:Float).and_return("FLOAT_INVOKED")
      setup_validation(:float, "FLOAT_INVOKED")
      expect_validation_success(test: "1.1")
    end

    describe "when input is uncoercible" do
      it "skips coercion" do
        setup_validation(:float, [])
        expect_validation_success(test: [])
      end
    end
  end

  describe ":date" do
    it_behaves_like "strict type coercion", :date, []

    it "coerces value with Date.parse" do
      allow(Date).to receive(:parse).and_return("DATE_INVOKED")
      setup_validation(:date, "DATE_INVOKED")
      expect_validation_success(test: "foo")
    end

    describe "when input is uncoercible" do
      it "skips coercion" do
        setup_validation(:date, [])
        expect_validation_success(test: [])
      end
    end
  end

  describe ":date_time" do
    it_behaves_like "strict type coercion", :date_time, []

    it "coerces value with DateTime.parse" do
      allow(DateTime).to receive(:parse).and_return("DATE_TIME_INVOKED")
      setup_validation(:date_time, "DATE_TIME_INVOKED")
      expect_validation_success(test: "foo")
    end

    describe "when input is uncoercible" do
      it "skips coercion" do
        setup_validation(:date_time, [])
        expect_validation_success(test: [])
      end
    end
  end

  describe ":time" do
    it_behaves_like "strict type coercion", :time, []

    it "coerces value with Time.parse" do
      allow(Time).to receive(:parse).and_return("TIME_INVOKED")
      setup_validation(:time, "TIME_INVOKED")
      expect_validation_success(test: "foo")
    end

    describe "when input is uncoercible" do
      it "skips coercion" do
        setup_validation(:time, [])
        expect_validation_success(test: [])
      end
    end
  end

  describe ":boolean" do
    it_behaves_like "strict type coercion", :boolean, []

    it "coerces to true when value is truthy" do
      [1, "1", "t", "T", true, "true", "y", "Y", "yes", "YES", "on", "ON"].each do |bool_true|
        setup_validation(:boolean, true)
        expect_validation_success(test: bool_true)
      end
    end

    it "coerces to false when value is falsy" do
      [0, "0", "f", "F", false, "false", "FALSE", "n", "N", "no", "NO", "off", "OFF"].each do |bool_false|
        setup_validation(:boolean, false)
        expect_validation_success(test: bool_false)
      end
    end

    describe "when input is uncoercible" do
      it "skips coercion" do
        setup_validation(:boolean, [])
        expect_validation_success(test: [])
      end
    end
  end

  describe ":array" do
    it_behaves_like "strict type coercion", :array, :foo

    it "skips coercion if value is uncoercible or an array" do
      setup_validation(:array, "string")
      expect_validation_success(test: "string")

      setup_validation(:array, [1, 2])
      expect_validation_success(test: [1, 2])
    end
  end

  describe ":hash" do
    it_behaves_like "strict type coercion", :hash, :foo

    it "skips coercion if value is uncoercible or a hash" do
      setup_validation(:hash, "string")
      expect_validation_success(test: "string")

      setup_validation(:hash, { foo: :bar })
      expect_validation_success(test: { foo: :bar })
    end
  end

  describe "result output" do
    it "returns coerced input" do
      validation.coerce(username: :string,
                         age: :integer,
                         admin: :boolean,
                         address: { street: :string, city: :string, zip: :integer },
                         tags: [:string])

      input = {
        username: :foo,
        admin: "YES",
        address: {
          street: 1,
          city: :belgrade,
          zip: "123456"
        },
        tags: [1, 2, 3]
      }

      result = validation.call(input)

      expected = {
        username: "foo",
        admin: true,
        address: {
          street: "1",
          city: "belgrade",
          zip: 123456
        },
        tags: %w(1 2 3)
      }

      expect(result.output).to eq(expected)
    end
  end

  describe "custom coercions" do
    let(:validation) { Class.new(Fend) }

    it "supports adding custom type coercions" do
      validation.plugin(:coercions) do
        coerce_to(:my_string) do |input|
          raise ArgumentError if input.nil?
          "my string"
        end
      end

      setup_validation(:my_string, "my string")
      expect_validation_success(test: "string")

      setup_validation(:strict_my_string, nil)
      expect { validation.call(test: nil) }.to raise_error(Fend::Plugins::Coercions::CoercionError, "cannot coerce nil to my_string")
    end
  end

  describe "overriding default coercion methods" do
    let(:validation) { Class.new(Fend) }

    it "supports overriding builtin coercion methods" do
      validation.plugin(:coercions) do
        coerce_to(:boolean) do |input|
          case input
          when "foo" then true
          when "bar" then false
          else
            input
          end
        end
      end

      setup_validation(:boolean, true)
      expect_validation_success(test: "foo")

      setup_validation(:boolean, false)
      expect_validation_success(test: "bar")

      setup_validation(:boolean, "foobar")
      expect_validation_success(test: "foobar")
    end
  end
end
