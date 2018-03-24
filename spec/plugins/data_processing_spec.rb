require "spec_helper"

RSpec.describe "data processing plugin" do
  let(:validation_class) { Class.new(Egis) { plugin :data_processing } }

  it "allows input processing" do
    validation_class.validate { }

    validation_class.process(:input) do |input|
      input.merge(foo: "foo", bar: "bar")
    end

    input_data = { test: "test" }

    input = validation_class.call(input_data).input

    expect(input).to eq(test: "test", foo: "foo", bar: "bar")
  end

  it "allows output processing" do
    validation_class.validate { }
    validation_class.process(:output) do |output|
      output.merge(foo: "foo", bar: "bar")
    end

    input_data = { test: "test" }

    output = validation_class.call(input_data).output

    expect(output).to eq(test: "test", foo: "foo", bar: "bar")
  end

  describe "built-in processings" do
    let(:validation) { validation_class.new }
    let(:raw_input) { validation.instance_variable_get(:"@_raw_data") }
    let(:input)     { validation.instance_variable_get(:"@_input_data") }
    let(:output)    { validation.instance_variable_get(:"@_output_data") }

    describe ":symbolize" do
      it "symbolizes data" do
        validation_class.plugin :data_processing, output: [:symbolize]

        input_data = {
          "username" => "foo",
          "first_name" => "bar",
          "last_name" => "baz",
          "address" => {
            "street" => "Elm Street",
            "city" => "Mordor",
            "zip" => 666,
            "directions" => [1.25, 2.34]
          },
          "tags" => [
            { "id" => 3, "name" => "tag3"},
            { "id" => 1, "name" => "tag1"}
          ]
        }

        expected = {
          username: "foo",
          first_name: "bar",
          last_name: "baz",
          address: {
            street: "Elm Street",
            city: "Mordor",
            zip: 666,
            directions: [1.25, 2.34]
          },
          tags: [
            { id: 3, name: "tag3" },
            { id: 1, name: "tag1" }
          ]
        }

        validation.call(input_data)

        expect(output).to eq(expected)
      end
    end

    describe ":stringify" do
      it "stringifies input" do
        validation_class.plugin :data_processing, input: [:stringify]

        input_data = {
          "username" => "foo",
          "first_name" => "bar",
          last_name: "baz",
          "address" => {
            "street" => "Elm Street",
            "city" => "Mordor",
            zip: 666,
            "directions" => [1.25, 2.34]
          },
          tags: [
            { id: 3, name: "tag3"},
            { "id" => 1, "name" => "tag1"}
          ]
        }

        expected = {
          "username" => "foo",
          "first_name" => "bar",
          "last_name" => "baz",
          "address" => {
            "street" => "Elm Street",
            "city" => "Mordor",
            "zip" => 666,
            "directions" => [1.25, 2.34]
          },
          "tags" => [
            { "id" => 3, "name" => "tag3" },
            { "id" => 1, "name" => "tag1" }
          ]
        }

        validation.call(input_data)

        expect(input).to eq(expected)
      end

      it "stringifies output" do
        validation_class.plugin :data_processing, output: [:stringify]

        input_data = {
          username: "foo",
          first_name: "bar",
          last_name: "baz",
          address: {
            street: "Elm Street",
            city: "Mordor",
            zip: 666,
            directions: [1.25, 2.34]
          },
          tags: [
            { id: 3, name: "tag3" },
            { id: 1, name: "tag1" }
          ]
        }

        expected = {
          "username" => "foo",
          "first_name" => "bar",
          "last_name" => "baz",
          "address" => {
            "street" => "Elm Street",
            "city" => "Mordor",
            "zip" => 666,
            "directions" => [1.25, 2.34]
          },
          "tags" => [
            { "id" => 3, "name" => "tag3" },
            { "id" => 1, "name" => "tag1" }
          ]
        }

        validation.call(input_data)

        expect(output).to eq(expected)
      end
    end

    describe ":dup" do
      it "deeply duplicates data" do
        validation_class.plugin :data_processing, input: [:dup], output: [:dup]

        input_data = {
          username: "foo",
          address: { details: { city: "bar" } },
          tags: [
            { id: 1 },
            { id: 2 }
          ]
        }

        validation.call(input_data)

        expect(raw_input).to be(input_data)

        expect(input).not_to be(input_data)
        expect(output).not_to be(input)

        expect(input[:address]).not_to be(input_data[:address])
        expect(output[:address]).not_to be(input[:address])

        expect(input[:address][:details]).not_to be(input_data[:address][:details])
        expect(output[:address][:details]).not_to be(input[:address][:details])

        expect(input[:tags]).not_to be(input_data[:tags])
        expect(output[:tags]).not_to be(input[:tags])

        expect(input[:tags][0]).not_to be(input_data[:tags][0])
        expect(output[:tags][0]).not_to be(input[:tags][0])

        expect(input[:tags][1]).not_to be(input_data[:tags][1])
        expect(output[:tags][1]).not_to be(input[:tags][1])
      end
    end

    describe ":freeze" do
      it "deep freezes data" do
        validation_class.plugin :data_processing, input: [:freeze], output: [:freeze]

        input_data = {
          username: "foo",
          address: { details: { city: "bar" } },
          tags: [
            { id: 1 },
            { id: 2 }
          ]
        }

        validation.call(input_data)

        expect(input_data).not_to be_frozen
        expect(raw_input).not_to be_frozen

        expect(output).not_to be(input)
        expect(input).to be_frozen
        expect(output).to be_frozen

        expect(input_data[:address]).not_to be_frozen

        expect(output[:address]).not_to be(input[:address])
        expect(input[:address]).to be_frozen
        expect(output[:address]).to be_frozen

        expect(input_data[:address][:details]).not_to be_frozen

        expect(output[:address][:details]).not_to be(input[:address][:details])
        expect(input[:address][:details]).to be_frozen
        expect(output[:address][:details]).to be_frozen


        expect(input_data[:tags]).not_to be_frozen

        expect(output[:tags]).not_to be(input[:tags])
        expect(input[:tags]).to be_frozen
        expect(output[:tags]).to be_frozen

        expect(input_data[:tags][0]).not_to be_frozen

        expect(output[:tags][0]).not_to be(input[:tags][0])
        expect(input[:tags][0]).to be_frozen
        expect(output[:tags][0]).to be_frozen

        expect(input_data[:tags][1]).not_to be_frozen

        expect(output[:tags][1]).not_to be(input[:tags][1])
        expect(input[:tags][1]).to be_frozen
        expect(output[:tags][1]).to be_frozen
      end
    end

    it "raises if processing name is invalid" do
      expect { validation_class.plugin :data_processing, input: [:invalid] }.to(
        raise_error(Egis::Error, "Built-in processing not found: ':invalid'")
      )
    end
  end
end
