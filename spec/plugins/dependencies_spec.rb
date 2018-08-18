require "spec_helper"

RSpec.describe "dependencies plugin" do
  let(:validation_class) { Class.new(Fend) { plugin :dependencies } }
  let(:validation) { validation_class.new }

  it "allows global dependencies" do
    validation_class.plugin :dependencies, foo: :bar

    expect(validation_class.opts[:dependencies]).to eq(foo: :bar)
  end

  it "injects specified deps in validation block" do
    validation_class.plugin :dependencies, foo: :bar

    validation_class.validate(inject: [:foo]) do |i, foo|
      i.params(:username) do |u|
        u.add_error("invalid_foo") unless foo.eql?(:bar)
      end
    end

    result = validation.call({})

    expect(result).to be_success
    expect(result.messages).to be_empty
  end

  it "raises error if :inject option is not an array" do
    expect{ validation_class.validate(inject: nil) }.to raise_error(ArgumentError, ":inject option value must be an array")
  end
end
