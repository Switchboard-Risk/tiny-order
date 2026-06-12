require "spec_helper"

RSpec.describe Product do
  subject(:product) do
    Product.new(sku: "WIDGET-1", name: "Widget", price_cents: 999, stock_quantity: 10)
  end

  it "reports available as stock minus reserved" do
    expect(product.available).to eq(10)
    product.reserve!(3)
    expect(product.available).to eq(7)
  end

  describe "#reserve!" do
    it "moves units from available to reserved" do
      product.reserve!(4)
      expect(product.reserved_quantity).to eq(4)
      expect(product.stock_quantity).to eq(10)
    end

    it "raises InsufficientStock rather than overselling" do
      expect { product.reserve!(11) }.to raise_error(InsufficientStock)
      expect(product.reserved_quantity).to eq(0)
    end

    it "counts already-reserved units against availability" do
      product.reserve!(8)
      expect { product.reserve!(3) }.to raise_error(InsufficientStock)
    end
  end

  describe "#release!" do
    it "returns reserved units to the available pool" do
      product.reserve!(5)
      product.release!(2)
      expect(product.reserved_quantity).to eq(3)
      expect(product.available).to eq(7)
    end

    it "raises when releasing more than is reserved" do
      product.reserve!(1)
      expect { product.release!(2) }.to raise_error(InsufficientStock)
    end
  end

  describe "#ship!" do
    it "permanently consumes reserved units from stock" do
      product.reserve!(4)
      product.ship!(4)
      expect(product.stock_quantity).to eq(6)
      expect(product.reserved_quantity).to eq(0)
      expect(product.available).to eq(6)
    end

    it "raises when shipping more than is reserved" do
      product.reserve!(2)
      expect { product.ship!(3) }.to raise_error(InsufficientStock)
    end
  end
end
