require "spec_helper"

RSpec.describe "external validation plugin" do
  let(:validation) { Class.new(Fend) { plugin :external_validation } }

  class AddressValidation < Fend
    validate do |i|
      i.param(:city) { |city| city.add_error("must be string") unless city.value.is_a?(String) }
      i.param(:street) { |street| street.add_error("must be string") unless street.value.is_a?(String) }
      i.param(:zip) { |zip| zip.add_error("must be integer") unless zip.value.is_a?(Integer) }
    end
  end

  it "supports external Fend validations" do
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

  it "supports custom objects" do
    validation.validate do |i|
      i.param(:username) do |username|
        username.add_error("must be present") if username.value.nil?
        username.validate_with(->(value) { ["must be string"] unless value.is_a?(String) })
      end
    end

    expect(validation.call(username: nil).messages).to eq(username: ["must be present", "must be string"])
  end

  context "when nested param are externaly validated" do
    it "supports combining of internal and external validations" do
      validation.validate do |i|
        i.param(:address) do |address|
          address.param(:city) { |c| c.add_error("invalid internaly") }

          address.validate_with(->(_) { { city: ["invalid externaly"] } })
        end
      end

      expect(validation.call({}).messages).to eq(address: { city: ["invalid internaly", "invalid externaly"] })
    end

    context "when param is invalid" do
      it "does not append messages" do
        validation.validate do |i|
          i.param(:address) do |address|
            address.add_error("must be hash")
            address.validate_with(->(_) { { city: ["invalid"] } })
          end
        end

        expect(validation.call({}).messages).to eq(address: ["must be hash"])
      end
    end

    context "when param is valid" do
      it "appends messages" do
        validation.validate do |i|
          i.param(:address) do |address|
            address.validate_with(->(_) { { city: ["invalid"] } })
          end
        end

        expect(validation.call({}).messages).to eq(address: { city: ["invalid"] })
      end
    end
  end
end
