require_relative "illegal_transition"

class Order
  attr_reader :id, :state, :line_items, :paid_at, :audit_log

  def initialize(id: nil, line_items: [])
    @id = id
    @line_items = line_items
    @state = :draft
    @paid_at = nil
    @audit_log = []
  end

  # Rebuild an order from persisted fields (used by the repository).
  def self.restore(id:, state:, line_items:, paid_at:, audit_log:)
    order = allocate
    order.instance_variable_set(:@id, id)
    order.instance_variable_set(:@state, state)
    order.instance_variable_set(:@line_items, line_items)
    order.instance_variable_set(:@paid_at, paid_at)
    order.instance_variable_set(:@audit_log, audit_log)
    order
  end

  def submit!
    transition!(from: :draft, to: :submitted)
  end

  def pay!
    transition!(from: :submitted, to: :paid)
    @paid_at = Time.now
  end

  def fulfill!
    transition!(from: :paid, to: :fulfilled)
  end

  def cancel!
    unless %i[draft submitted].include?(@state)
      raise IllegalTransition, "cannot cancel from #{@state}"
    end
    log_transition(@state, :canceled)
    @state = :canceled
  end

  # Total in integer cents.
  def total
    line_items.sum { |li| li.quantity * li.unit_price_cents }
  end

  private

  def transition!(from:, to:)
    unless @state == from
      raise IllegalTransition, "cannot go #{@state} → #{to}"
    end
    log_transition(from, to)
    @state = to
  end

  def log_transition(from, to)
    @audit_log << { at: Time.now, from: from, to: to }
  end
end
