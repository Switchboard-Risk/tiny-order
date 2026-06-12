require "spec_helper"

RSpec.describe OrderService do
  let(:db) { fresh_db }
  let(:service) { described_class.new(db) }

  before do
    service.products.save(Product.new(sku: "WIDGET-1", name: "Widget", price_cents: 999, stock_quantity: 10))
    service.products.save(Product.new(sku: "RARE-1", name: "Rare", price_cents: 5000, stock_quantity: 1))
  end

  def available(sku)
    service.products.find(sku).available
  end

  describe "#add_item" do
    it "snapshots the product price onto the line item" do
      order = service.create
      service.add_item(order.id, "WIDGET-1", 2)

      line = service.find(order.id).line_items.first
      expect(line.unit_price_cents).to eq(999)
    end

    it "does not reserve stock until submit" do
      order = service.create
      service.add_item(order.id, "WIDGET-1", 2)
      expect(available("WIDGET-1")).to eq(10)
    end

    it "raises for an unknown sku" do
      order = service.create
      expect { service.add_item(order.id, "NOPE", 1) }.to raise_error(ArgumentError)
    end
  end

  describe "#submit!" do
    it "reserves stock for each line item" do
      order = service.create
      service.add_item(order.id, "WIDGET-1", 3)
      service.submit!(order.id)

      expect(service.find(order.id).state).to eq(:submitted)
      expect(available("WIDGET-1")).to eq(7)
    end

    it "aggregates duplicate skus when reserving" do
      order = service.create
      service.add_item(order.id, "WIDGET-1", 2)
      service.add_item(order.id, "WIDGET-1", 3)
      service.submit!(order.id)

      expect(available("WIDGET-1")).to eq(5)
    end

    it "leaves the order in draft and reserves nothing when stock is insufficient" do
      order = service.create
      service.add_item(order.id, "WIDGET-1", 1)
      service.add_item(order.id, "RARE-1", 2) # only 1 in stock

      expect { service.submit!(order.id) }.to raise_error(InsufficientStock)
      expect(service.find(order.id).state).to eq(:draft)
      expect(available("WIDGET-1")).to eq(10)
      expect(available("RARE-1")).to eq(1)
    end
  end

  describe "#cancel!" do
    it "touches no stock when canceling a draft order" do
      order = service.create
      service.add_item(order.id, "WIDGET-1", 4)
      service.cancel!(order.id)

      expect(service.find(order.id).state).to eq(:canceled)
      expect(available("WIDGET-1")).to eq(10)
    end
  end

  describe "#fulfill!" do
    it "permanently decrements stock" do
      order = service.create
      service.add_item(order.id, "WIDGET-1", 4)
      service.submit!(order.id)
      service.pay!(order.id)
      service.fulfill!(order.id)

      product = service.products.find("WIDGET-1")
      expect(service.find(order.id).state).to eq(:fulfilled)
      expect(product.stock_quantity).to eq(6)
      expect(product.reserved_quantity).to eq(0)
      expect(product.available).to eq(6)
    end
  end

  it "persists orders and stock across service instances on a shared db" do
    order = service.create
    service.add_item(order.id, "WIDGET-1", 2)
    service.submit!(order.id)

    reopened = described_class.new(db)
    expect(reopened.find(order.id).state).to eq(:submitted)
    expect(reopened.products.find("WIDGET-1").available).to eq(8)
  end
end
