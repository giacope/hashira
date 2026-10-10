module App
  module Orders
    class Order
      def price = Pricing::Quote.new
      def recheck = Pricing::Quote.new
      def total = Pricing::Quote.new
    end
  end
end
