module App
  module Service
    class Checkout
      def total = Domain::Order.all.sum(&:amount) + Tax.new.rate
    end
  end
end
