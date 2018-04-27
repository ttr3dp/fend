require "spec_helper"

RSpec.describe "collective params plugin" do
  let(:validation) { Class.new(Fend) { plugin :collective_params } }
  let(:param) { validation::Param.new(:input, foo: :bar) }

  it "validates nested params" do
    param.params(:foo, :bar, :baz) do |foo, bar, baz|
      foo.add_error("invalid foo") unless foo.value.eql?(:bar)
      bar.add_error("invalid bar")
      baz.add_error("invalid baz")
    end

    expect(param.errors).to eq(bar: ["invalid bar"], baz: ["invalid baz"])
  end
end
