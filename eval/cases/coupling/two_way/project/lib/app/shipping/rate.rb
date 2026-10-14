module App
  module Shipping
    class Rate
      def bill = Billing::Invoice.new
      def refund = Billing::Invoice.new
    end
  end
end
