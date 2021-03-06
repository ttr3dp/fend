require "spec_helper"

RSpec.describe "full messages plugin" do
  let(:validation) { Class.new(Fend) { plugin :full_messages } }

  it "prepends param name to error messages" do
    validation.validate do |i|
      i.params(:username) do |username|
        username.add_error("must be present")
        username.add_error("must be string")
      end

      i.params(:address) do |address|
        address.params(:city) { |city| city.add_error "must be present" }
        address.params(:street) { |street| street.add_error "must be present" }
      end

      i.params(:tags) do |tags|
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
        i.params(:tags) do |tags|
          tags.each { |tag| tag.add_error "must be string" }
        end
      end

      full_messages = validation.call(tags: [1]).full_messages

      expect(full_messages).to eq(tags: { 0 => ["tag must be string"] })
    end

    it "skips key modification if param is not an array" do
      validation.validate do |i|
        i.params(:tags) do |tags|
          tags.params(:foo) { |foo| foo.add_error "is invalid" }
        end
      end

      full_messages = validation.call(tags: {}).full_messages

      expect(full_messages).to eq(tags: { foo: ["foo is invalid"] })
    end
  end

  context "base errors" do
    before do
      validation.plugin :base_errors

      validation.validate do |i|
        add_base_error("should be skipped")
        i.params(:username) do |username|
          username.add_error("must be present")
        end
      end
    end

    it "skips base error messages" do
      expect(validation.call({}).full_messages).to eq(
        base: ["should be skipped"],
        username: ["username must be present"]
      )
    end

    context "when custom key is specified" do
      it "skips base error messages" do
        validation.plugin :base_errors, key: :be_key

        expect(validation.call({}).full_messages).to eq(
          be_key: ["should be skipped"],
          username: ["username must be present"]
        )
      end
    end
  end
end
