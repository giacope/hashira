module App
  class Stock
    def levels(items, sold)
      counts = items.map { |item| item.quantity }
      counts -= sold.map { |item| item.quantity } if sold.any?
      @audit.record("levels #{counts.sum} for #{items.count}")
      counts
    end
  end
end
