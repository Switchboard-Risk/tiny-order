# frozen_string_literal: true

class Product
  attr_accessor :sku, :name, :price_cents, :stock_quantity, :reserved_quantity

  def initialize(sku:, name:, price_cents:, stock_quantity: 0, reserved_quantity: 0)
    @sku = sku
    @name = name
    @price_cents = price_cents
    @stock_quantity = stock_quantity
    @reserved_quantity = reserved_quantity
  end
end

class LineItem
  attr_accessor :sku, :quantity, :unit_price_cents

  def initialize(sku:, quantity:, unit_price_cents:)
    @sku = sku
    @quantity = quantity
    @unit_price_cents = unit_price_cents
  end

  def subtotal_cents
    quantity * unit_price_cents
  end
end

class Order
  STATES = %i[draft submitted paid fulfilled canceled].freeze

  attr_reader :state
  attr_accessor :line_items, :paid_at

  def initialize(state: :draft, line_items: [], paid_at: nil)
    self.state = state
    @line_items = line_items.dup
    @paid_at = paid_at
  end

  def state=(value)
    unless STATES.include?(value)
      raise ArgumentError, "state must be one of: #{STATES.join(', ')}"
    end

    @state = value
  end

  def add_line_item(line_item)
    line_items << line_item
    self
  end

  def total_cents
    line_items.sum(&:subtotal_cents)
  end
end
