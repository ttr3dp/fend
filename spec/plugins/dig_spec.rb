require "spec_helper"

RSpec.describe "dig plugin" do
  let(:validation) { Class.new(Fend) { plugin :dig } }
  let(:param_class) { validation::Param }

  it "fetches nested values from hash" do
    param = param_class.new({ address: { street: "Elm street", city: { name: "Mordor", zip: 666 } } })

    expect(param.dig(:address)).to eq(street: "Elm street", city: { name: "Mordor", zip: 666 })
    expect(param.dig(:address, :street)).to eq("Elm street")
    expect(param.dig(:address, :city)).to eq(name: "Mordor", zip: 666)
    expect(param.dig(:address, :city, :name)).to eq("Mordor")
    expect(param.dig(:address, :city, :zip)).to eq(666)
  end

  it "fetches nested values from array" do
    param = param_class.new([:root_0, [:nested_1_0, :nested_1_1, [:nested_2_0, :nested_2_1]], :root_2])

    expect(param.dig(0)).to eq(:root_0)
    expect(param.dig(1)).to eq([:nested_1_0, :nested_1_1, [:nested_2_0, :nested_2_1]])
    expect(param.dig(1, 0)).to eq(:nested_1_0)
    expect(param.dig(1, 1)).to eq(:nested_1_1)
    expect(param.dig(1, 2)).to eq([:nested_2_0, :nested_2_1])
    expect(param.dig(1, 2, 0)).to eq(:nested_2_0)
    expect(param.dig(1, 2, 1)).to eq(:nested_2_1)
    expect(param.dig(2)).to eq(:root_2)
  end

  it "feches nested values from mixed enumerables" do
    param = param_class.new(
      {
        username: "foo",
        address: {
          street: "Elm street",
          details: { location: [1111, 2222] }
        },
        tags: [
          { id: 1, name: "tag 1" }
        ]
      }
    )

    expect(param.dig(:username)).to eq("foo")

    expect(param.dig(:address)).to eq(street: "Elm street", details: { location: [1111, 2222] })
    expect(param.dig(:address, :street)).to eq("Elm street")
    expect(param.dig(:address, :details)).to eq(location: [1111, 2222])
    expect(param.dig(:address, :details, :location)).to eq([1111, 2222])
    expect(param.dig(:address, :details, :location, 0)).to eq(1111)
    expect(param.dig(:address, :details, :location, 1)).to eq(2222)

    expect(param.dig(:tags)).to eq([{ id: 1, name: "tag 1" }])
    expect(param.dig(:tags, 0)).to eq({ id: 1, name: "tag 1" })
    expect(param.dig(:tags, 0, :id)).to eq(1)
    expect(param.dig(:tags, 0, :name)).to eq("tag 1")
  end

  context "when path is invalid" do
    it "returns nil" do
      param = param_class.new({})

      expect(param.dig(:adress)).to be_nil
      expect(param.dig(:adress, :city)).to be_nil

      expect(param.dig(0, 1, 2)).to be_nil
    end
  end
end
