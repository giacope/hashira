module App
  module Web
    class OrdersPage
      def self.path = "/orders"

      def rows = Domain::Order.all

      def checkout = Service::Checkout.new.total
    end
  end
end
