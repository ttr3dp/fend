require "spec_helper"

RSpec.describe "base errors plugin" do
  let(:validation) do
    Class.new(Fend) do
      plugin :base_errors

      validate do |i|
        add_base_error("base error")

        i.params(:test) do |_|
          add_base_error("another base error")
        end
      end
    end
  end

  it "adds errors under :base key by default" do
    expect(validation.call({}).messages).to eq(base: ["base error", "another base error"])
  end

  it "allows setting the base errors key" do
    validation.plugin :base_errors, key: :foo

    expect(validation.call({}).messages).to eq(foo: ["base error", "another base error"])
  end

  it "uses inherited key if one is not specified" do
    validation.plugin :base_errors, key: :bar

    subclass = Class.new(validation)
    subclass.validate { |_| add_base_error("base error") }

    expect(subclass.call({}).messages).to eq(bar: ["base error"])
  end
end
