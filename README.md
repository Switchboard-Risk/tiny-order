# tiny-orders

## What is in the file

- `Product` holds product fields.
- `LineItem` holds line item fields and a small subtotal helper.
- `Order` holds order fields, exposes a state enum, and can append line items.

## Basic usage

```ruby
require_relative "./tiny_orders"

product = Product.new(
  sku: "WIDGET-1",
  name: "Standard Widget",
  price_cents: 999,
  stock_quantity: 10,
  reserved_quantity: 0
)

line_item = LineItem.new(
  sku: product.sku,
  quantity: 2,
  unit_price_cents: product.price_cents
)

order = Order.new(
  state: :draft,
  line_items: [],
  paid_at: nil
)

order.add_line_item(line_item)

puts product.name
puts line_item.quantity
puts order.state
puts order.total_cents
```

## Fields

- `Product`: `sku`, `name`, `price_cents`, `stock_quantity`, `reserved_quantity`
- `LineItem`: `sku`, `quantity`, `unit_price_cents`
- `Order`: `state`, `line_items`, `paid_at`

## Small API

- `Order::STATES`
- `order.state = :submitted`
- `order.add_line_item(line_item)`
- `line_item.subtotal_cents`
- `order.total_cents`
