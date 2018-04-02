require "spec_helper"

RSpec.describe "validate_with plugin" do
  let(:validation) { Class.new(Fend) { plugin :validate_with } }

  class AddressValidation < Fend
    validate do |i|
      i.param(:city) { |city| city.add_error("must be string") unless city.value.is_a?(String) }
      i.param(:street) { |street| street.add_error("must be string") unless street.value.is_a?(String) }
      i.param(:zip) { |zip| zip.add_error("must be integer") unless zip.value.is_a?(Integer) }
    end
  end

  it "delegates param validation to specified validation and merges messages to itself" do
    validation.validate do |i|
      i.param(:username) { |username| username.add_error("missing") if username.value.nil? }

      i.param(:address) { |address| address.validate_with(AddressValidation) }
    end

    expected_messages = {
      username: ["missing"],
      address: {
        city: ["must be string"],
        street: ["must be string"],
        zip: ["must be integer"],
      }
    }
    result = validation.call({})

    expect(result).to be_failure
    expect(result.messages).to eq(expected_messages)

    expect(validation.call(username: "foo", address: { street: "Elm street", city: "Mordor", zip: 999})).to be_success
  end
end
