# tiny-orders

A small order app in pure Ruby: an order **state machine** backed by a **product
catalog with inventory** and **SQLite persistence**. Clone it, seed the catalog,
push orders through their lifecycle, and watch stock get reserved and drawn down.

## Requirements

- Ruby 3.2.5
- Bundler

If you don't have Ruby, the easiest way to install it on macOS or Linux is via [rbenv](https://github.com/rbenv/rbenv) or [asdf](https://asdf-vm.com/):

```
rbenv install 3.2.5     # or: asdf install ruby 3.2.5
gem install bundler
```

## Setup

```
bundle install
```

## Quick start

```
bin/orders seed                 # load the sample catalog
bin/orders catalog              # see products, prices, and stock
bin/orders create               # -> Created order #1 (state: draft)
bin/orders add 1 WIDGET-1 2     # add 2x WIDGET-1 (price snapshotted onto the order)
bin/orders submit 1             # reserves 2 units of WIDGET-1
bin/orders pay 1
bin/orders fulfill 1            # permanently decrements stock
bin/orders show 1               # full detail + audit log
bin/orders list                 # all orders
```

Orders and stock live in a SQLite file at `db/orders.sqlite3` and persist between
runs. (The file is created on first use; delete it to start fresh.)

## How it behaves like a real order app

- **Catalog** — every line item is backed by a real `Product` (sku, name, price,
  stock). You can't order a SKU that doesn't exist.
- **Inventory that can't oversell** — `submit!` reserves stock all-or-nothing. If
  any product is short, the whole submit fails with `InsufficientStock` and the
  order stays in `draft`. Fulfilling an order turns its reservations into a
  permanent stock decrement.
- **Money as integer cents** — prices are stored as cents and snapshotted onto the
  line item at add-time, so an order's total stays correct even if the catalog
  price later changes.

```
bin/orders demo                 # self-contained end-to-end run (in-memory DB)
```

The demo seeds a throwaway in-memory catalog, runs an order
`draft → submitted → paid → fulfilled`, and prints the catalog before and after so
you can see stock drop.

## All commands

```
bin/orders seed              Load the sample catalog into the store
bin/orders catalog           List products with price and stock
bin/orders create            Create a new draft order, print its id
bin/orders add ID SKU QTY    Add QTY of SKU to draft order ID
bin/orders submit ID         Submit order ID (reserves stock)
bin/orders pay ID            Mark order ID paid
bin/orders fulfill ID        Fulfill order ID (decrements stock)
bin/orders cancel ID         Cancel order ID
bin/orders show ID           Show one order in detail
bin/orders list              List all orders
bin/orders demo              Self-contained end-to-end run (in-memory)
bin/orders help              Show this message
```

## Run the tests

```
bundle exec rspec
```

## What's in here

Domain (plain Ruby, no SQL):

- `lib/order.rb` — the state machine. Legal transitions: `draft → submitted → paid
  → fulfilled`, plus `draft → canceled` and `submitted → canceled`. Every
  transition is recorded in `audit_log`.
- `lib/product.rb` — a catalog product that owns its inventory invariants
  (`reserve!`, `release!`, `ship!`, `available`); refuses to oversell.
- `lib/line_item.rb` — a single row in an order (sku, quantity, unit price in cents).
- `lib/illegal_transition.rb` / `lib/insufficient_stock.rb` — the errors raised when
  a state transition or a reservation isn't allowed.

Persistence & coordination:

- `lib/db.rb` — SQLite connection + schema bootstrap.
- `lib/product_repository.rb` / `lib/order_repository.rb` — map domain objects ↔ rows.
- `lib/order_service.rb` — runs each stock-touching transition (submit/cancel/fulfill)
  and its persistence inside one SQLite transaction, so the order and the affected
  products commit together or not at all.
- `db/seeds.rb` — the sample catalog loaded by `bin/orders seed`.

## Coding exercise

This repo doubles as a coding exercise. You don't need to know Ruby going in — use
whatever editor, tooling, and AI assistants you'd normally reach for. We care about how
you navigate an unfamiliar codebase, make decisions, and verify your work, not about
trivia.

Get oriented first: run `bundle install`, then `bin/orders seed`, try the commands
listed above, and run `bundle exec rspec` to see the suite pass.

### Task 1 — Look into a bug report

A ticket came in from the ops team:

> GADGET-7 is showing out of stock, but I'm staring at 8 of them in the bin. The
> available counts keep drifting down through the day and don't bounce back even when
> nothing's shipped. Pretty sure it started after we ran a batch of test orders that
> didn't go through. — Dana, ops

Reproduce it, track down the cause, fix it, and add a test so it can't come back.

### Task 2 — Add a "returns" feature

Today an order moves `draft → submitted → paid → fulfilled`. We want to support
**returns**: after an order has been fulfilled, a customer can send some or all of it
back, and those items go back into the catalog's available stock.

Build it end to end — domain logic, persistence, a CLI command, and tests.

**Your implementation must handle these cases:**

- **Partial returns, across more than one trip.** Someone who bought 2 of an item can
  return 1 now and 1 later. Returning more than was bought (counting every trip) is
  rejected.
- **Returns have a condition, and only good ones restock.** A return records whether
  each item came back in good condition or damaged. Good-condition items go back into
  sellable stock — a brand new order can then add and submit that same unit. Damaged
  items are recorded but never become available for sale again.

**Decisions we're leaving to you** — make a reasonable call and explain why in your note:

- What state an order ends up in after a partial return vs. a full one.
- How you model and track damaged units, and whether a damaged return is still refunded.
- Whether and how you surface the refunded amount.
- Anything else the cases above leave ambiguous.

We care more about your judgment and how you confirm the feature actually works than
about one specific "correct" answer.

### Task 3 — Add a "cart"

Before someone places an order, they build up a **cart**: add items, change their mind
and remove some, see a running total, and eventually **check out** — at which point the
cart becomes a real order that goes through the existing flow (`draft → submitted → …`).

Build it end to end — domain logic, persistence, CLI commands, and tests.

**Your implementation must handle these cases:**

- **Add items, remove items, and see the cart's running total** before anything is
  ordered.
- **Checking out turns the cart into an order** that can then be submitted, paid, and
  fulfilled like any other — and that order is still bound by the catalog's stock rules
  (an order can never reserve more than is in stock).

**Decisions we're leaving to you** — make a reasonable call and explain why in your note:

- An order can never oversell. Does that same limit apply when *adding to a cart*, or can
  a cart hold more of an item than is currently available? Decide, and say why.
- What a cart belongs to (a session? a customer?), and what happens to it after checkout.
- Anything else the cases above leave ambiguous.

We care more about your reasoning here than about matching some particular answer.
