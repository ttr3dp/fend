require "spec_helper"

RSpec.describe "dependencies plugin" do
  let(:validation_class) { Class.new(Fend) { plugin :dependencies } }
  let(:validation) { validation_class.new }

  it "allows global dependencies" do
    validation_class.plugin :dependencies, foo: :bar

    expect(validation_class.opts[:dependencies]).to eq(foo: :bar)
  end

  it "combines global and user-defined deps on instance level" do
    validation_class.plugin :dependencies, foo: :bar

    validation.deps[:test_dep] = "test dep"

    expect(validation.deps).to eq(foo: :bar, test_dep: "test dep")
  end

  it "injects specified deps in validation block" do
    validation_class.plugin :dependencies, foo: :bar

    validation_class.validate(inject: %i(foo test_dep)) do |i, foo, test_dep|
      i.params(:username) do |u|
        u.add_error("invalid_foo") unless foo.eql?(:bar) && test_dep.eql?("test_dep")
      end
    end

    validation.deps[:test_dep] = "test_dep"

    result = validation.call({})

    expect(result).to be_success
    expect(result.messages).to be_empty

    validation.deps[:test_dep] = "no_test_dep"

    result = validation.call({})

    expect(result).to be_failure
    expect(result.messages).to eq(username: ["invalid_foo"])
  end

  it "raises error if :inject option is not an array" do
    expect{ validation_class.validate(inject: nil) }.to raise_error(ArgumentError, ":inject option value must be an array")
  end
end
