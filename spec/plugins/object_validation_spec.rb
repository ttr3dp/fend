require "spec_helper"

RSpec.describe "object validation plugin" do
  let(:validation_class) { Class.new(Fend) { plugin :object_validation } }
  let(:input) { Struct.new(:username, :email).new("john", nil) }

  it "enables object attrs and methods validation" do
    validation_class.validate do |i|
      i.attrs(:username, :email) do |username, email|
        username.add_error("cannot be shorter than 5 chars") unless username.value.length >= 5
        email.add_error("must be string") unless email.value.is_a?(String)
      end
    end

    result = validation_class.call(input)
    expect(result).to be_failure
    expect(result.messages).to eq(username: ["cannot be shorter than 5 chars"], email: ["must be string"])
    expect(result.output).to eq input
  end

  it "raises if input method is undefined" do
    validation_class.validate { |i| i.attrs(:oops) { } }

    expect{ validation_class.call(input) }.to raise_error(NoMethodError, /undefined method `oops'/)
  end

  context "when attr is a hash" do
    let(:input) { Struct.new(:address).new(street: "Elm Street", city: "Mordor") }

    it "enables nested params fetching with #param" do
      validation_class.validate do |i|
        i.attrs(:address) do |address|
          address.params(:street) { |s| s.add_error("invalid") unless s.value == "Elm Street" }
          address.params(:city) { |c| c.add_error("invalid") unless c.value == "Mordor" }
        end
      end

      expect(validation_class.call(input)).to be_success
    end
  end
end
