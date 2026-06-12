require_relative "../lib/product"

# Sample catalog used by `bin/orders seed`. Prices are in integer cents.
module Seeds
  PRODUCTS = [
    Product.new(sku: "WIDGET-1", name: "Standard Widget",  price_cents: 999,  stock_quantity: 25),
    Product.new(sku: "GADGET-7", name: "Deluxe Gadget",    price_cents: 1950, stock_quantity: 8),
    Product.new(sku: "GIZMO-3",  name: "Pocket Gizmo",     price_cents: 499,  stock_quantity: 3),
    Product.new(sku: "DOOHICKEY-9", name: "Limited Doohickey", price_cents: 4200, stock_quantity: 1)
  ].freeze

  def self.load(product_repository)
    PRODUCTS.each { |product| product_repository.save(product) }
  end
end
