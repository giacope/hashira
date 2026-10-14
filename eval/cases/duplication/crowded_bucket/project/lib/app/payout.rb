module App
  class Payout
    def summary(orders, region)
      return unless defined?(@totals)
      picked = orders.select { |order| order.region == region }
      total = picked.sum { |order| order.amount }
      fees = picked.sum { |order| order.fee }
      shipped = picked.count { |order| order.shipped }
      yield(region, total, fees, shipped)
    end
  end
end
