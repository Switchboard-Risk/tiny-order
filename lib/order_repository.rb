require "time"
require_relative "order"
require_relative "line_item"

# Persists Orders across the `orders`, `line_items`, and `order_audit_log`
# tables and reconstructs them. A new order (id == nil) is INSERTed and gets its
# id assigned; an existing order is UPDATEd. Child rows (line items, audit log)
# are rewritten on each save — simple and correct for this size of app.
#
# This repository does not open its own transaction; callers that need
# atomicity (e.g. OrderService) wrap save in db.transaction.
class OrderRepository
  def initialize(db)
    @db = db
  end

  def find(id)
    row = @db.get_first_row("SELECT * FROM orders WHERE id = ?", [id])
    row && to_order(row)
  end

  def all
    @db.execute("SELECT id FROM orders ORDER BY id").map { |r| find(r["id"]) }
  end

  def save(order)
    if order.id.nil?
      @db.execute(
        "INSERT INTO orders (state, paid_at) VALUES (?, ?)",
        [order.state.to_s, order.paid_at&.iso8601]
      )
      order.instance_variable_set(:@id, @db.last_insert_row_id)
    else
      @db.execute(
        "UPDATE orders SET state = ?, paid_at = ? WHERE id = ?",
        [order.state.to_s, order.paid_at&.iso8601, order.id]
      )
    end

    write_line_items(order)
    write_audit_log(order)
    order
  end

  private

  def write_line_items(order)
    @db.execute("DELETE FROM line_items WHERE order_id = ?", [order.id])
    order.line_items.each do |li|
      @db.execute(
        "INSERT INTO line_items (order_id, sku, quantity, unit_price_cents) VALUES (?, ?, ?, ?)",
        [order.id, li.sku, li.quantity, li.unit_price_cents]
      )
    end
  end

  def write_audit_log(order)
    @db.execute("DELETE FROM order_audit_log WHERE order_id = ?", [order.id])
    order.audit_log.each do |entry|
      @db.execute(
        "INSERT INTO order_audit_log (order_id, at, from_state, to_state) VALUES (?, ?, ?, ?)",
        [order.id, entry[:at].iso8601, entry[:from]&.to_s, entry[:to].to_s]
      )
    end
  end

  def to_order(row)
    Order.restore(
      id: row["id"],
      state: row["state"].to_sym,
      line_items: load_line_items(row["id"]),
      paid_at: row["paid_at"] && Time.parse(row["paid_at"]),
      audit_log: load_audit_log(row["id"])
    )
  end

  def load_line_items(order_id)
    @db.execute("SELECT * FROM line_items WHERE order_id = ? ORDER BY id", [order_id]).map do |r|
      LineItem.new(sku: r["sku"], quantity: r["quantity"], unit_price_cents: r["unit_price_cents"])
    end
  end

  def load_audit_log(order_id)
    @db.execute("SELECT * FROM order_audit_log WHERE order_id = ? ORDER BY id", [order_id]).map do |r|
      {
        at: Time.parse(r["at"]),
        from: r["from_state"]&.to_sym,
        to: r["to_state"].to_sym
      }
    end
  end
end
