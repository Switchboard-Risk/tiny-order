require "spec_helper"

RSpec.describe Order do
  let(:line_items) { [LineItem.new(sku: "WIDGET-1", quantity: 1, unit_price_cents: 1000)] }
  let(:order) { Order.new(id: 1, line_items: line_items) }

  describe "initial state" do
    it "starts in :draft" do
      expect(order.state).to eq(:draft)
    end

    it "has nil paid_at" do
      expect(order.paid_at).to be_nil
    end

    it "has an empty audit log" do
      expect(order.audit_log).to eq([])
    end
  end

  describe "#submit!" do
    it "moves :draft to :submitted" do
      order.submit!
      expect(order.state).to eq(:submitted)
    end

    it "raises when called from :submitted" do
      order.submit!
      expect { order.submit! }.to raise_error(IllegalTransition)
    end
  end

  describe "#pay!" do
    it "moves :submitted to :paid" do
      order.submit!
      order.pay!
      expect(order.state).to eq(:paid)
    end

    it "sets paid_at" do
      order.submit!
      order.pay!
      expect(order.paid_at).to be_a(Time)
    end

    it "raises when called from :draft" do
      expect { order.pay! }.to raise_error(IllegalTransition)
    end
  end

  describe "#fulfill!" do
    it "moves :paid to :fulfilled" do
      order.submit!
      order.pay!
      order.fulfill!
      expect(order.state).to eq(:fulfilled)
    end

    it "raises when called from :submitted" do
      order.submit!
      expect { order.fulfill! }.to raise_error(IllegalTransition)
    end
  end

  describe "#cancel!" do
    it "cancels from :draft" do
      order.cancel!
      expect(order.state).to eq(:canceled)
    end

    it "cancels from :submitted" do
      order.submit!
      order.cancel!
      expect(order.state).to eq(:canceled)
    end

    it "raises from :paid" do
      order.submit!
      order.pay!
      expect { order.cancel! }.to raise_error(IllegalTransition)
    end
  end

  describe "#audit_log" do
    it "records each transition with from, to, and a timestamp" do
      order.submit!
      order.pay!

      expect(order.audit_log.length).to eq(2)
      expect(order.audit_log[0]).to include(from: :draft, to: :submitted)
      expect(order.audit_log[1]).to include(from: :submitted, to: :paid)
      expect(order.audit_log[0][:at]).to be_a(Time)
    end
  end

  describe "#total" do
    it "sums quantity * unit_price_cents across line items" do
      items = [
        LineItem.new(sku: "A", quantity: 2, unit_price_cents: 500),
        LineItem.new(sku: "B", quantity: 3, unit_price_cents: 400)
      ]
      order = Order.new(id: 99, line_items: items)
      expect(order.total).to eq(2200)
    end

    it "returns 0 for an order with no line items" do
      order = Order.new(id: 100, line_items: [])
      expect(order.total).to eq(0)
    end
  end
end
