require "spec_helper"

RSpec.describe LineItem do
  it "initializes with sku, quantity, and unit_price_cents" do
    li = LineItem.new(sku: "WIDGET-1", quantity: 3, unit_price_cents: 150)

    expect(li.sku).to eq("WIDGET-1")
    expect(li.quantity).to eq(3)
    expect(li.unit_price_cents).to eq(150)
  end

  it "exposes attributes as readers" do
    li = LineItem.new(sku: "Z", quantity: 5, unit_price_cents: 999)

    expect(li).to respond_to(:sku, :quantity, :unit_price_cents)
  end

  it "computes its subtotal in cents" do
    li = LineItem.new(sku: "Z", quantity: 4, unit_price_cents: 250)

    expect(li.subtotal_cents).to eq(1000)
  end
end
