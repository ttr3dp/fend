require "ostruct"

require "spec_helper"

RSpec.shared_examples "validation options custom message" do |option_name, input, options|
  it "accepts :message option" do
    validation.validate { |i| i.param(:test) { |t| t.validate(option_name => options.merge(message: "custom message")) } }

    expect(validation.call(test: input).messages).to eq(test: ["custom message"])
  end
end

RSpec.describe "validation options plugin" do
  let(:validation) { Class.new(Fend) { plugin :validation_options } }

  describe "it allows passing validation options" do
    describe ":absence" do
      it "validates param value absence" do
        validation.validate { |i| i.param(:test) { |test| test.validate(absence: true) } }

        expect(validation.call({})).to be_success
        expect(validation.call(test: "test")).to be_failure

      end

      include_examples "validation options custom message", :absence, "test", absence: {}
    end

    describe ":presence" do
      it "validates param value presence" do
        validation.validate { |i| i.param(:test) { |test| test.validate(presence: true) } }

        expect(validation.call(test: "test")).to be_success
        expect(validation.call({})).to be_failure
      end

      include_examples "validation options custom message", :presence, nil, {}
    end

    describe ":acceptance" do
      it "validates param value acceptance" do
        validation.validate { |i| i.param(:test) { |test| test.validate(acceptance: true) } }


        [1, "1", true, "true", "TRUE", :yes, "YES", "yes"].each do |valid_value|
          expect(validation.call(test: valid_value)).to be_success
        end
        expect(validation.call(test: :foo)).to be_failure
      end

      context "with :as option" do
        it "validates acceptance against option value" do
          validation.validate { |i| i.param(:test) { |test| test.validate(acceptance: { as: [:foo, :bar] }) } }

          %i(foo bar).each do |valid_value|
            expect(validation.call(test: valid_value)).to be_success
          end

          [1, "1", true, "true", "TRUE", :yes, "YES", "yes"].each do |invalid_value|
            expect(validation.call(test: invalid_value)).to be_failure
          end
          expect(validation.call(test: "test")).to be_failure
        end
      end

      include_examples "validation options custom message", :acceptance, nil, {}
    end

    describe ":equality" do
      it "validates param value equality" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(equality: 5)
            test.validate(equality: { value: 5 })
          end
        end

        expect(validation.call(test: 5)).to be_success
        expect(validation.call({}).messages[:test].count).to eq(2)
        expect(validation.call({}).messages[:test].uniq).to eq(["must be equal to '5'"])
      end

      include_examples "validation options custom message", :equality, nil, value: 5
    end

    describe ":exact_length" do
      it "validates param value exact length" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(exact_length: 5)
            test.validate(exact_length: { of: 5 })
            test.validate(exact_length: { value: 5 })
          end
        end

        expect(validation.call(test: [1, 2, 3, 4, 5])).to be_success
        expect(validation.call({test: 1}).messages[:test].count).to eq(3)
        expect(validation.call({}).messages[:test].uniq).to eq(["length must be equal to 5"])
      end

      include_examples "validation options custom message", :exact_length, nil, of: 5
    end

    describe ":exclusion" do
      it "validates param value exclusion from specified list of values" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(exclusion: [:foo, :bar])
            test.validate(exclusion: { from: [:foo, :bar] })
            test.validate(exclusion: { value: [:foo, :bar] })
          end
        end

        expect(validation.call(test: :baz)).to be_success
        expect(validation.call(test: :foo).messages[:test].count).to eq(3)
        expect(validation.call(test: :bar).messages[:test].count).to eq(3)
        expect(validation.call(test: :foo).messages[:test].uniq).to eq(["cannot be one of: foo, bar"])
      end

      include_examples "validation options custom message", :exclusion, 1, from: [1, 2]
    end

    describe ":format" do
      it "validates param value format" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(format: /\A(foo|bar)\z/)
            test.validate(format: { with: /\A(foo|bar)\z/ })
            test.validate(format: { value: /\A(foo|bar)\z/ })
          end
        end

        expect(validation.call(test: :foo)).to be_success
        expect(validation.call(test: :bar)).to be_success
        expect(validation.call(test: :baz).messages[:test].count).to eq(3)
        expect(validation.call(test: :baz).messages[:test].uniq).to eq(["is in invalid format"])
      end

      include_examples "validation options custom message", :format, "bar", with: /\A(foo)\z/i
    end

    describe ":greater_than" do
      it "validates param value > comparison value" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(greater_than: 2)
            test.validate(greater_than: { value: 2 })
          end
        end

        expect(validation.call(test: 3)).to be_success
        expect(validation.call(test: 1).messages[:test].count).to eq(2)
        expect(validation.call(test: 1).messages[:test].uniq).to eq(["must be greater than 2"])
      end

      include_examples "validation options custom message", :greater_than, nil, value: 2
    end

    describe ":greater_than_or_equal_to" do
      it "validates param value >= comparison value" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(greater_than_or_equal_to: 2)
            test.validate(greater_than_or_equal_to: { value: 2 })
            test.validate(gteq: 2)
            test.validate(gteq: { value: 2 })
          end
        end

        expect(validation.call(test: 2)).to be_success
        expect(validation.call(test: 3)).to be_success
        expect(validation.call(test: 1).messages[:test].count).to eq(4)
        expect(validation.call(test: 1).messages[:test].uniq).to eq(["must be greater than or equal to 2"])
      end

      include_examples "validation options custom message", :gteq, nil, value: 2
    end

    describe ":inclusion" do
      it "validates param value inclusion in specified list of values" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(inclusion: [:foo, :bar])
            test.validate(inclusion: { in: [:foo, :bar] })
            test.validate(inclusion: { value: [:foo, :bar] })
          end
        end

        expect(validation.call(test: :foo)).to be_success
        expect(validation.call(test: :bar)).to be_success
        expect(validation.call(test: :baz).messages[:test].count).to eq(3)
        expect(validation.call(test: :baz).messages[:test].uniq).to eq(["must be one of: foo, bar"])
      end

      include_examples "validation options custom message", :inclusion, nil, in: [1, 2]
    end

    describe ":length range" do
      it "validates param lhs <= value <= rhs" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(length_range: 3..4)
            test.validate(length_range: { within: 3..4 })
            test.validate(length_range: { value: 3..4 })
          end
        end

        expect(validation.call(test: "foo")).to be_success
        expect(validation.call(test: "foob")).to be_success
        expect(validation.call(test: "foobar").messages[:test].count).to eq(3)
        expect(validation.call(test: "foobar").messages[:test].uniq).to eq(["length must be between 3 and 4"])
      end

      include_examples "validation options custom message", :length_range, nil, within: 1..2
    end

    describe ":less_than" do
      it "validates param value < comparison value" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(less_than: 2)
            test.validate(less_than: { value: 2 })
          end
        end

        expect(validation.call(test: 1)).to be_success
        expect(validation.call(test: 2).messages[:test].count).to eq(2)
        expect(validation.call(test: 2).messages[:test].uniq).to eq(["must be less than 2"])
      end

      include_examples "validation options custom message", :less_than, nil, value: 2
    end

    describe ":less_than_or_equal_to" do
      it "validates param value <= comparison value" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(less_than_or_equal_to: 2)
            test.validate(less_than_or_equal_to: { value: 2 })
            test.validate(lteq: 2)
            test.validate(lteq: { value: 2 })
          end
        end

        expect(validation.call(test: 1)).to be_success
        expect(validation.call(test: 2)).to be_success
        expect(validation.call(test: 3).messages[:test].count).to eq(4)
        expect(validation.call(test: 3).messages[:test].uniq).to eq(["must be less than or equal to 2"])
      end

      include_examples "validation options custom message", :lteq, nil, value: 2
    end

    describe ":max_length" do
      it "validates param value max length" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(max_length: 2)
            test.validate(max_length: { of: 2 })
            test.validate(max_length: { value: 2 })
          end
        end

        expect(validation.call(test: "rb")).to be_success
        expect(validation.call(test: "ruby").messages[:test].count).to eq(3)
        expect(validation.call(test: "ruby").messages[:test].uniq).to eq(["length cannot be greater than 2"])
      end

      include_examples "validation options custom message", :max_length, nil, value: 2
    end

    describe ":min_length" do
      it "validates param value min length" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(min_length: 2)
            test.validate(min_length: { of: 2 })
            test.validate(min_length: { value: 2 })
          end
        end

        expect(validation.call(test: "rb")).to be_success
        expect(validation.call(test: "r").messages[:test].count).to eq(3)
        expect(validation.call(test: "r").messages[:test].uniq).to eq(["length cannot be less than 2"])
      end

      include_examples "validation options custom message", :min_length, nil, value: 2
    end

    describe ":type" do
      it "validates param value kind" do
        validation.validate do |i|
          i.param(:test) do |test|
            test.validate(type: String)
            test.validate(type: { of: String })
            test.validate(type: { value: String })
          end
        end

        expect(validation.call(test: "foo")).to be_success
        expect(validation.call(test: 1).messages[:test].count).to eq(3)
        expect(validation.call(test: 1).messages[:test].uniq).to eq(["must be string"])
      end

      include_examples "validation options custom message", :type, nil, of: String
    end

    describe ":allow_nil" do
      context "when option value is true" do
        it "skips validation if value is nil" do
          validation.validate do |i|
            i.param(:test) do |test|
              test.validate(type: String, allow_nil: true)
            end
          end

          expect(validation.call(test: nil)).to be_success
        end
      end

      context "when option value is not true" do
        it "does not skip validation if value is nil" do
          [:foo, false, "foo"].each do |not_true_value|
            validation.validate do |i|
              i.param(:test) do |test|
                test.validate(type: String, allow_nil: not_true_value)
              end
            end

            expect(validation.call(test: nil)).to be_failure
          end
        end
      end
    end

    describe ":allow_blank" do
      let(:blank_values) do
        [nil, "", "   ", "\r", "\n", "\t", " \n\r\t ", [], {}, false, OpenStruct.new(empty?: true)]
      end

      context "when option value is true" do
        it "skips validation if value is blank" do
          blank_values.each do |blank_value|
            validation.validate do |i|
              i.param(:test) do |test|
                test.validate(presence: true, allow_blank: true)
              end
            end

            expect(validation.call(test: blank_value)).to be_success
          end
        end
      end

      context "when option value is not true" do
        it "does not skip validation if value is nil" do
          blank_values.each do |blank_value|
            [:foo, false, "foo"].each do |not_true_value|
              validation.validate do |i|
                i.param(:test) do |test|
                  test.validate(presence: true, allow_blank: not_true_value)
                end
              end

              expect(validation.call(test: blank_value)).to be_failure
            end
          end
        end
      end
    end
  end

  context "when option is invalid" do
    it "raises error" do
      validation.validate { |i| i.param(:test) { |t| t.validate(foo: true) } }

      expect { validation.call({}) }.to raise_error(Fend::Error, "undefined validation method 'foo'")
    end

  end
end
