module App
  class Report
    def summary(orders, region)
      return unless defined?(@totals)
      picked = orders.select { |order| order.region == region }
      total = picked.sum { |order| order.amount }
      tax = picked.sum { |order| order.tax }
      yield(region, total, tax)
    end
  end
end
