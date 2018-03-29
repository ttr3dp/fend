require "spec_helper"
require "ostruct"

RSpec.shared_examples "validation helper that accepts custom error messsage" do |method_name, input_value, *args|
  it "uses specified message instead of default one" do
    validation.validate { |i| i.param(:test) { |t| t.public_send("validate_#{method_name}", *args, message: "custom message") } }
    expect(errors(test: input_value)).to eq(["custom message"])
  end
end

RSpec.shared_examples "validation helper" do |valid_values, invalid_values, error_message|
  context "when value is valid" do
    it "does not append errors" do
      valid_values.each do |valid_value|
        expect(errors(test: valid_value)).to be_nil
      end
    end
  end

  context "when value is invalid" do
    it "appends errors" do
      invalid_values.each do |invalid_value|
        expect(errors(test: invalid_value).count).to eq(1)
        expect(errors(test: invalid_value)).to eq([error_message])
      end
    end
  end
end

RSpec.describe "validation helpers plugin" do
  let(:validation) { Class.new(Fend) { plugin :validation_helpers } }

  def validate(input)
    validation.call(input)
  end

  def errors(input)
    validate(input).messages[:test]
  end

  describe "#absence" do
    before { validation.validate { |i| i.param(:test) { |test| test.validate_absence } } }

    it_behaves_like("validation helper",
                    [nil, "", "   ", "\r", "\n", "\t", " \n\r\t ", [], {}, false, OpenStruct.new(empty?: true)],
                    [1, "test", "  test   ", :test, Object.new, OpenStruct.new(empty?: false), [1, 2, 3], { one: 1 }, true],
                    "must be absent")

    it_behaves_like("validation helper that accepts custom error messsage", :absence, 1)
  end

  describe "#acceptance" do
    before { validation.validate { |i| i.param(:test) { |test| test.validate_acceptance } } }

    it_behaves_like("validation helper",
                    [1, "1", true, "true", "TRUE", :yes, "YES", "yes"],
                    [nil, "", "accepted", Object.new],
                    "must be accepted")

    it_behaves_like("validation helper that accepts custom error messsage", :acceptance, nil)

    context "when :as option is passed" do
      it "checks if value matches the one/s passed as :as option" do
        validation.validate { |i| i.param(:test) { |t| t.validate_acceptance as: ["accepted", "accept"] } }

        expect(errors(test: "accepted")).to be_nil
        expect(errors(test: "accept")).to be_nil

        [1, "1", true, "true", "TRUE", :yes, "YES", "yes"].each do |invalid_value|
          expect(errors(test: invalid_value).count).to eq(1)
          expect(errors(test: invalid_value)).to eq(["must be accepted"])
        end
      end
    end
  end

  describe "#validate_equality" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_equality "equal" } } }

    it_behaves_like("validation helper", ["equal"], ["not equal"], "must be equal to 'equal'")
    it_behaves_like("validation helper that accepts custom error messsage", :equality, nil, "equal")
  end

  describe "#validate_exact_length" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_exact_length 4 } } }

    it_behaves_like("validation helper",
                    ["test", [1, 2, 3, 4], { one: 1, two: 2, three: 3, four: 4 }, OpenStruct.new(length: 4)],
                    ["foo", [1, 2, 3], { one: 1, two: 2, three: 3, four: 4, five: 5, six: 6 }, nil, Object.new, OpenStruct.new(length: 10)],
                    "length must be equal to 4")

    it_behaves_like("validation helper that accepts custom error messsage", :exact_length, [1], 4)
  end

  describe "#validate_exclusion" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_exclusion %w(test retest overtest) } } }

    it_behaves_like("validation helper",
                    ["valid", "supervalid", "ubervalid"],
                    ["test", "retest", "overtest"],
                    "cannot be one of: test, retest, overtest")

    it_behaves_like("validation helper that accepts custom error messsage", :exclusion, :test, [:test])
  end

  describe "#validate_format" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_format(/\A[a-z0-9][-a-z0-9]{1,19}\z/i) } } }

    it_behaves_like("validation helper",
                    ["TeSt99", "99test", String.new.center(20, "A")],
                    ["-*test", "{{test", String.new.center(21, "A")],
                    "is in invalid format")

    it_behaves_like("validation helper that accepts custom error messsage", :format, nil, /\A[a-z]\z/i )
  end

  describe "#validate_greater_than" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_greater_than 4 } } }

    it_behaves_like("validation helper", [5, 5.5, 4.1], [2, 4, nil, "five", Object.new], "must be greater than 4")
    it_behaves_like("validation helper that accepts custom error messsage", :greater_than, nil, 4)
  end

  describe "#validate_greater_than_or_equal_to" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_gteq 4 } } }

    it_behaves_like("validation helper", [4, 4.1, 5], [3.9, 3, nil, "five", Object.new], "must be greater than or equal to 4")
    it_behaves_like("validation helper that accepts custom error messsage", :gteq, nil, 4)

    it "is aliased as #validate_gteq" do
      input = validation::Param.new({})
      expect(input.method(:validate_gteq)).to eq(input.method(:validate_greater_than_or_equal_to))
    end
  end

  describe "#validate_inclusion" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_inclusion %w(test retest overtest) } } }

    it_behaves_like("validation helper", %w(test retest overtest), %w(nope no no\ way), "must be one of: test, retest, overtest")
    it_behaves_like("validation helper that accepts custom error messsage", :inclusion, nil, [1])
  end

  describe "#validate_length_range" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_length_range 3..5 } } }

    it_behaves_like("validation helper",
                    ["foo", "test", [1, 2, 3, 4], { one: 1, two: 2, three: 3, four: 4, five: 5 }, OpenStruct.new(length: 4)],
                    ["foobar", [1, 2], { one: 1, two: 2 }, OpenStruct.new(length: 1)],
                    "length must be between 3 and 5")

    it_behaves_like("validation helper that accepts custom error messsage", :length_range, nil, 1..3)
  end

  describe "#validate_less_than" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_less_than 4 } } }

    it_behaves_like("validation helper", [3, 3.9], [5, 4.1, nil, "five", Object.new], "must be less than 4")
    it_behaves_like("validation helper that accepts custom error messsage", :less_than, nil, 3)
  end

  describe "#less_than_or_equal_to" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_lteq 4 } } }

    it_behaves_like("validation helper", [4, 3.9, 3], [4.1, 5, nil, "five", Object.new], "must be less than or equal to 4")
    it_behaves_like("validation helper that accepts custom error messsage", :lteq, nil, 3)

    it "is aliased as #validate_lteq" do
      input = validation::Param.new({})
      expect(input.method(:validate_lteq)).to eq(input.method(:validate_less_than_or_equal_to))
    end
  end

  describe "#validate_max_length" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_max_length 4 } } }

    it_behaves_like("validation helper",
                    ["test", "one", [1, 2, 3, 4], { one: 1, two: 2, three: 3, four: 4 }, OpenStruct.new(length: 3)],
                    ["test1", [1, 2, 3, 4, 5], { one: 1, two: 2, three: 3, four: 4, five: 5 }, nil, Object.new, OpenStruct.new(length: 6)],
                    "length cannot be greater than 4")
    it_behaves_like("validation helper that accepts custom error messsage", :max_length, "foo", 2)
  end


  describe "#min_length" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_min_length 4 } } }

    it_behaves_like("validation helper",
                    ["test", "test1", [1, 2, 3, 4, 5], { one: 1, two: 2, three: 3, four: 4 }, OpenStruct.new(length: 5)],
                    ["one", [1, 2, 3], { one: 1, two: 2 }, nil, Object.new, OpenStruct.new(length: 1)],
                    "length cannot be less than 4")
    it_behaves_like("validation helper that accepts custom error messsage", :min_length, "foo", 5)
  end

  describe "#presence" do
    before { validation.validate { |i| i.param(:test) { |t| t.validate_presence } } }

    it_behaves_like("validation helper",
                    [1, "test", " test     ", :test, Object.new, OpenStruct.new(empty?: false), [1, 2, 3], { one: 1 }, true],
                    [nil, "", "    ", "\r", "\n", "\t", " \n\r\t  ", [], {}, false, OpenStruct.new(empty?: true)],
                    "must be present")
    it_behaves_like("validation helper that accepts custom error messsage", :presence, nil)
  end

  describe "#type" do
    describe "when value is of specified type" do
      it "does not append errors" do
        [:integer, :Integer, Integer, "integer", "Integer"].each do |type_ref|
          validation.validate { |i| i.param(:test) { |t| t.validate_type type_ref } }

          expect(errors(test: 1)).to be_nil
        end

        [:string, :String, String, "string", "String"].each do |type_ref|
          validation.validate { |i| i.param(:test) { |t| t.validate_type type_ref } }

          expect(errors(test: "1")).to be_nil
        end

        [:boolean, "boolean", "BOOL", "BOOLEAN"].each do |type_ref|
          validation.validate { |i| i.param(:test) { |t| t.validate_type type_ref } }

          expect(errors(test: true)).to be_nil
          expect(errors(test: false)).to be_nil
        end

        [:decimal, :DECIMAL, "decimal", "DECIMAL"].each do |type_ref|
          validation.validate { |i| i.param(:test) { |t| t.validate_type type_ref } }

          expect(errors(test: 1.1)).to be_nil
        end

        MyObject = Object
        [:my_object, :MyObject, "my_object", "MyObject", MyObject].each do |type_ref|
          validation.validate { |i| i.param(:test) { |t| t.validate_type type_ref } }

          expect(errors(test: MyObject)).to be_nil
        end
      end
    end

    describe "when value is invalid" do
      it "appends errors" do
        [:string, :String, String, "string", "String"].each do |type_ref|
          validation.validate { |i| i.param(:test) { |t| t.validate_type type_ref } }

          expect(errors(test: nil)).to eq(["must be string"])
        end
      end
    end

    it_behaves_like("validation helper that accepts custom error messsage", :type, nil, :boolean)
  end

  describe ":default_messages option" do
    let(:helpers) { [:absence, :acceptance, :equality, :exact_length, :exclusion,
                          :format, :greater_than, :greater_than_or_equal_to, :inclusion, :length_range,
                          :less_than, :less_than_or_equal_to, :max_length, :min_length, :presence, :type] }
    let(:messages) { helpers.each_with_object({}) { |key, result| result[key] = "custom #{key} message" } }

    let(:validation) do
      Class.new(Fend) do
        validate do |i|
          i.param(:absence)                  { |p| p.validate_absence }
          i.param(:acceptance)               { |p| p.validate_acceptance }
          i.param(:equality)                 { |p| p.validate_equality "EQUAL" }
          i.param(:exact_length)             { |p| p.validate_exact_length 1 }
          i.param(:exclusion)                { |p| p.validate_exclusion ["NOPE"] }
          i.param(:format)                   { |p| p.validate_format(/\A(valid)\z/i) }
          i.param(:greater_than)             { |p| p.validate_greater_than 100 }
          i.param(:greater_than_or_equal_to) { |p| p.validate_gteq 100 }
          i.param(:inclusion)                { |p| p.validate_inclusion [true, false] }
          i.param(:length_range)             { |p| p.validate_length_range 99..100 }
          i.param(:less_than)                { |p| p.validate_less_than 2 }
          i.param(:less_than_or_equal_to)    { |p| p.validate_lteq 2 }
          i.param(:max_length)               { |p| p.validate_max_length 2 }
          i.param(:min_length)               { |p| p.validate_min_length 100 }
          i.param(:presence)                 { |p| p.validate_presence }
          i.param(:type)                     { |p| p.validate_type :integer }
        end
      end
    end

    it "uses user-defined messages instead of default ones" do
      validation.plugin :validation_helpers, default_messages: messages

      input    = helpers.each_with_object({}) { |key, result| result[key] = key == :presence ? nil : "NOPE" }
      expected = messages.transform_values(&method(:Array))

      expect(validation.call(input).messages).to eq(expected)
    end
  end
end
