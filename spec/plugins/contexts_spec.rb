require "spec_helper"

RSpec.describe "contexts plugin" do
  let(:validation_class) do
    Class.new(Fend) do
      plugin :contexts

      validate do |i|
        i.param(:username) do |username|
          context(:foo) do
            username.add_error("foo context error")
          end

          context(:bar) do
            username.add_error("bar context error")
          end

          context(:default) do
            username.add_error("default context error")
          end
        end
      end
    end
  end

  it "executes context specific block" do
    result = validation_class.new(context: :foo).call({})
    expect(result.messages).to eq(username: ["foo context error"])

    result = validation_class.new(context: :bar).call({})
    expect(result.messages).to eq(username: ["bar context error"])
  end

  context "when context is not specified" do
    it "executes default context block" do
      result = validation_class.call({})
      expect(result.messages).to eq(username: ["default context error"])
    end
  end

  context "with overriden initializer" do
    let(:validation_class) do
      Class.new(Fend) do
        plugin :contexts

        validate do |i|
          i.param(:username) do |username|
            context(:foo) do
              username.add_error("foo context error")
            end
          end
        end

        def initialize(foo, opts)
          super

          @foo = foo
        end
      end
    end

    it "uses contexts properly" do
      result = validation_class.new("foo", context: :foo).call({})
      expect(result.messages).to eq(username: ["foo context error"])
    end
  end
end
