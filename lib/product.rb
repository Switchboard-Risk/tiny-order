require_relative "insufficient_stock"

# A catalog product with its own inventory invariants.
#
# Inventory is tracked as two numbers:
#   stock_quantity     — units physically on hand
#   reserved_quantity  — units promised to submitted-but-not-yet-fulfilled orders
#
# available = stock_quantity - reserved_quantity is what a new order may claim.
# Product owns the rule that you can never reserve more than is available.
class Product
  attr_reader :sku, :name, :price_cents, :stock_quantity, :reserved_quantity

  def initialize(sku:, name:, price_cents:, stock_quantity: 0, reserved_quantity: 0)
    @sku = sku
    @name = name
    @price_cents = price_cents
    @stock_quantity = stock_quantity
    @reserved_quantity = reserved_quantity
  end

  def available
    @stock_quantity - @reserved_quantity
  end

  # Promise `qty` units to an order. Raises rather than overselling.
  def reserve!(qty)
    if qty > available
      raise InsufficientStock,
            "#{sku}: cannot reserve #{qty} (only #{available} available)"
    end
    @reserved_quantity += qty
  end

  # Return a previously reserved `qty` to the available pool (e.g. on cancel).
  def release!(qty)
    if qty > @reserved_quantity
      raise InsufficientStock,
            "#{sku}: cannot release #{qty} (only #{@reserved_quantity} reserved)"
    end
    @reserved_quantity -= qty
  end

  # Permanently consume a reservation when the order is fulfilled: the units
  # leave both the shelf and the reserved pool.
  def ship!(qty)
    if qty > @reserved_quantity
      raise InsufficientStock,
            "#{sku}: cannot ship #{qty} (only #{@reserved_quantity} reserved)"
    end
    @reserved_quantity -= qty
    @stock_quantity -= qty
  end
end
