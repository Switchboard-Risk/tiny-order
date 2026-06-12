$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "line_item"
require "illegal_transition"
require "insufficient_stock"
require "order"
require "product"
require "db"
require "product_repository"
require "order_repository"
require "order_service"

module DBHelper
  # A fresh, empty in-memory database for each example. ":memory:" gives every
  # connection its own private database, so examples are fully isolated with no
  # truncation needed.
  def fresh_db
    DB.connect(":memory:")
  end
end

RSpec.configure do |config|
  config.include DBHelper
end
