module App
  module Billing
    class Invoice
      def ship = Shipping::Rate.new
    end
  end
end
