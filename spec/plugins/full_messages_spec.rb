require "spec_helper"

RSpec.describe "full messages plugin" do
  let(:validation) { Class.new(Fend) { plugin :full_messages } }

  it "prepends param name to error messages" do
    validation.validate do |i|
      param(:username) do |username|
        username.add_error("must be present")
        username.add_error("must be string")
      end

      param(:address) do |address|
        address.param(:city) { |city| city.add_error "must be present" }
        address.param(:street) { |street| street.add_error "must be present" }
      end

      param(:tags) do |tags|
        tags.each { |tag| tag.add_error "must be string" }
      end
    end

    result = validation.call(tags: [1])

    expected_messages = {
      username: ["username must be present", "username must be string"],
      address: {
        city: ["city must be present"],
        street: ["street must be present"]
      },
      tags: {
        0 => ["0 must be string"]
      }
    }

    expect(result.full_messages).to eq(expected_messages)
  end

  describe ":array_member_names" do
    let(:validation) { Class.new(Fend) { plugin :full_messages, array_member_names: { tags: :tag } } }

    it "uses specified names instead of array member index" do
      validation.validate do |i|
        param(:tags) do |tags|
          tags.each { |tag| tag.add_error "must be string" }
        end
      end

      full_messages = validation.call(tags: [1]).full_messages

      expect(full_messages).to eq(tags: { 0 => ["tag must be string"] })
    end

    it "skips key modification if param is not an array" do
      validation.validate do |i|
        param(:tags) do |tags|
          tags.param(:foo) { |foo| foo.add_error "is invalid" }
        end
      end

      full_messages = validation.call(tags: {}).full_messages

      expect(full_messages).to eq(tags: { foo: ["foo is invalid"] })
    end
  end
end
