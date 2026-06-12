require "sqlite3"

# SQLite connection helper + idempotent schema bootstrap.
#
# DB.connect returns a ready-to-use handle with the schema applied. Pass
# ":memory:" (the default in specs) for an ephemeral database, or a file path
# for a persistent store.
module DB
  DEFAULT_PATH = File.expand_path("../db/orders.sqlite3", __dir__)

  SCHEMA = <<~SQL
    CREATE TABLE IF NOT EXISTS products (
      sku               TEXT    PRIMARY KEY,
      name              TEXT    NOT NULL,
      price_cents       INTEGER NOT NULL,
      stock_quantity    INTEGER NOT NULL DEFAULT 0,
      reserved_quantity INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS orders (
      id      INTEGER PRIMARY KEY AUTOINCREMENT,
      state   TEXT    NOT NULL,
      paid_at TEXT
    );

    CREATE TABLE IF NOT EXISTS line_items (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id         INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      sku              TEXT    NOT NULL,
      quantity         INTEGER NOT NULL,
      unit_price_cents INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS order_audit_log (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id   INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      at         TEXT    NOT NULL,
      from_state TEXT,
      to_state   TEXT    NOT NULL
    );
  SQL

  def self.connect(path = DEFAULT_PATH)
    db = SQLite3::Database.new(path.to_s)
    db.results_as_hash = true
    db.execute("PRAGMA foreign_keys = ON")
    bootstrap(db)
    db
  end

  def self.bootstrap(db)
    db.execute_batch(SCHEMA)
    db
  end
end
