require_relative "product"

# Maps Product domain objects to/from the `products` table.
class ProductRepository
  def initialize(db)
    @db = db
  end

  def find(sku)
    row = @db.get_first_row("SELECT * FROM products WHERE sku = ?", [sku])
    row && to_product(row)
  end

  def all
    @db.execute("SELECT * FROM products ORDER BY sku").map { |row| to_product(row) }
  end

  # Insert or update a product by sku.
  def save(product)
    @db.execute(<<~SQL, sku_params(product))
      INSERT INTO products (sku, name, price_cents, stock_quantity, reserved_quantity)
      VALUES (:sku, :name, :price_cents, :stock_quantity, :reserved_quantity)
      ON CONFLICT(sku) DO UPDATE SET
        name              = excluded.name,
        price_cents       = excluded.price_cents,
        stock_quantity    = excluded.stock_quantity,
        reserved_quantity = excluded.reserved_quantity
    SQL
    product
  end

  private

  def sku_params(product)
    {
      "sku" => product.sku,
      "name" => product.name,
      "price_cents" => product.price_cents,
      "stock_quantity" => product.stock_quantity,
      "reserved_quantity" => product.reserved_quantity
    }
  end

  def to_product(row)
    Product.new(
      sku: row["sku"],
      name: row["name"],
      price_cents: row["price_cents"],
      stock_quantity: row["stock_quantity"],
      reserved_quantity: row["reserved_quantity"]
    )
  end
end
