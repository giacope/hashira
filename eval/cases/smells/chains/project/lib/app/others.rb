module App
  class Lint
    def on_send(node) = node.loc.selector.source

    def add(range) = range
  end

  Point = Data.define(:x, :y) do
    def shifted = with(x: x + 1)
  end

  class Shape
    attr_reader :point
  end

  class Plotter
    def x(shape) = shape.point.shifted
  end

  class Query
    attr_reader :query

    def where(clause) = self

    def run = []
  end

  class Search
    def run(query) = query.query.run
  end

  class Item
    def price = 1
  end

  class Invoice
    attr_reader :items

    def first_price = items.first.price
  end
end
