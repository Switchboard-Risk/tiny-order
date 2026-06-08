require_relative "order"
require_relative "line_item"
require_relative "order_repository"
require_relative "product_repository"

# Coordinates the order FSM with inventory and persistence.
#
# The Order aggregate owns state-transition rules and Product owns inventory
# invariants; this service is where they meet. State changes that touch stock
# (submit/cancel/fulfill) run inside a single SQLite transaction so the order
# and the affected products commit together — or not at all.
class OrderService
  def initialize(db)
    @db = db
    @orders = OrderRepository.new(db)
    @products = ProductRepository.new(db)
  end

  attr_reader :orders, :products

  # Create and persist a fresh empty draft order; returns it with its id set.
  def create
    @orders.save(Order.new)
  end

  # Add a line item to a draft order, snapshotting the product's current price.
  def add_item(order_id, sku, quantity)
    product = @products.find(sku) or raise ArgumentError, "no such product: #{sku}"
    order = load!(order_id)
    order.line_items << LineItem.new(
      sku: product.sku,
      quantity: quantity,
      unit_price_cents: product.price_cents
    )
    @orders.save(order)
  end

  # draft -> submitted, reserving stock all-or-nothing.
  def submit!(order_id)
    order = load!(order_id)
    @db.transaction do
      order.submit! # validate state first
      adjust_inventory(order) { |product, qty| product.reserve!(qty) }
      @orders.save(order)
    end
    order
  end

  # submitted -> paid (no inventory effect).
  def pay!(order_id)
    order = load!(order_id)
    order.pay!
    @orders.save(order)
  end

  # paid -> fulfilled, converting reservations into permanent decrements.
  def fulfill!(order_id)
    order = load!(order_id)
    @db.transaction do
      order.fulfill!
      adjust_inventory(order) { |product, qty| product.ship!(qty) }
      @orders.save(order)
    end
    order
  end

  # Cancel a draft or submitted order.
  def cancel!(order_id)
    order = load!(order_id)
    @db.transaction do
      order.cancel!
      @orders.save(order)
    end
    order
  end

  def find(order_id)
    @orders.find(order_id)
  end

  def all
    @orders.all
  end

  private

  def load!(order_id)
    @orders.find(order_id) or raise ArgumentError, "no such order: ##{order_id}"
  end

  # Apply an inventory operation to each referenced product, aggregating
  # quantities by sku (so duplicate line items count together), then persist
  # the touched products. Runs inside the caller's transaction.
  def adjust_inventory(order)
    quantities_by_sku(order).each do |sku, qty|
      product = @products.find(sku) or raise ArgumentError, "no such product: #{sku}"
      yield product, qty
      @products.save(product)
    end
  end

  def quantities_by_sku(order)
    order.line_items.each_with_object(Hash.new(0)) do |li, totals|
      totals[li.sku] += li.quantity
    end
  end
end
